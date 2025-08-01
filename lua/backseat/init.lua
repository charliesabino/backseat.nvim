local M = {}

M.command_history = {}
M.instructions = "" -- Store user instructions

M.config = {
	api_key = nil,
	analysis_interval = 15,
	max_history_size = 50,
	endpoint = "https://api.anthropic.com/v1/messages",
	model = "claude-3-5-haiku-latest",
	enable_monitoring = true,
}

-- Get the data directory for persisting instructions
local data_dir = vim.fn.stdpath("data") .. "/backseat"
local instructions_file = data_dir .. "/instructions.txt"
local timer = vim.loop.new_timer()

-- Load saved instructions
local function load_instructions()
	vim.fn.mkdir(data_dir, "p") -- Create directory if it doesn't exist
	local f = io.open(instructions_file, "r")
	if f then
		M.instructions = f:read("*all")
		f:close()
	end
end

-- Save instructions to file
local function save_instructions()
	vim.fn.mkdir(data_dir, "p") -- Create directory if it doesn't exist
	local f = io.open(instructions_file, "w")
	if f then
		f:write(M.instructions)
		f:close()
	end
end

local function create_command_monitor()
	-- Only record actual commands, not every keypress
	local pending_keys = {}
	local last_update = 0

	vim.on_key(function(key)
		if not M.config.enable_monitoring then
			return
		end

		local now = vim.loop.now()
		if vim.fn.mode() == "n" then
			-- Debounce to avoid excessive processing
			if now - last_update < 50 then -- 50ms debounce
				return
			end

			local translated = vim.fn.keytrans(key)
			-- Only record meaningful keys (ignore cursor movements, etc)
			if translated:match("^[^<]") or translated:match("^<C%-") or translated:match("^<CR>") then
				table.insert(pending_keys, translated)

				-- Batch process keys after a short delay
				vim.defer_fn(function()
					if #pending_keys > 0 then
						local command = table.concat(pending_keys)
						table.insert(M.command_history, command)
						pending_keys = {}

						-- Trim history if it gets too large
						if #M.command_history > M.config.max_history_size then
							table.remove(M.command_history, 1)
						end
					end
				end, 100)
			end

			last_update = now
		end
	end)
end

local function make_anthropic_request(prompt)
	if not M.config.api_key then
		vim.notify("Backseat: API key not configured", vim.log.levels.ERROR)
		return
	end

	local ok, curl = pcall(require, "plenary.curl")
	if not ok then
		vim.notify("Backseat: plenary.nvim is required for API requests", vim.log.levels.ERROR)
		return
	end

	local headers = {
		["x-api-key"] = M.config.api_key,
		["anthropic-version"] = "2023-06-01",
		["content-type"] = "application/json",
	}

	local body = vim.json.encode({
		model = M.config.model,
		max_tokens = 128,
		messages = {
			{
				role = "user",
				-- content must be an array of blocks
				content = {
					{
						type = "text",
						text = prompt,
					},
				},
			},
		},
	})

	curl.post(M.config.endpoint, {
		headers = headers,
		body = body,
		callback = function(response)
			if response.status == 200 then
				local data = vim.json.decode(response.body)
				if
					data
					and data.content
					and data.content[1]
					and not string.find(data.content[1].text or "", "No feedback")
				then
					vim.schedule(function()
						vim.notify("Backseat Analysis:\n" .. data.content[1].text, vim.log.levels.INFO)
					end)
					-- Clear command history after analysis
					M.command_history = {}
				end
			else
				vim.schedule(function()
					vim.notify("Backseat: API request failed - " .. response.status, vim.log.levels.ERROR)
				end)
			end
		end,
	})
end

local function analyze_command_history()
	local recent_commands = M.get_recent_commands(#M.command_history)

	if #recent_commands == 0 or M.instructions == "" then
		return
	end

	local command_list = {}
	for _, cmd in ipairs(recent_commands) do
		-- Filter out non-printable characters and ensure valid UTF-8
		local clean_command = cmd:gsub("[%c%z]", ""):gsub("[\194-\244][\128-\191]*", "")
		-- local clean_command = fixUTF8(cmd)
		if clean_command ~= "" then
			-- print(clean_command)
			table.insert(command_list, clean_command)
		end
	end

	local prompt = string.format(
		[[You are a Neovim expert. Your task is to analyze a list of recent commands and provide feedback based *only* on the user's instructions.

-- User Instructions
%s

-- Recent Commands
%s

Analyze the commands against the instructions.
- Provide feedback only for deviations from the instructions.
- All feedback must be incredibly terse. As much as possible, respond along the lines of "Use X instead of Y." with nothing else appended. Your response should fit in a small text box if possible.
- If there are no deviations or no feedback is necessary, respond with the exact phrase "No feedback" and nothing else.
]],
		M.instructions,
		table.concat(command_list, "\n")
	)

	make_anthropic_request(prompt)
end

local function start_periodic_analysis()
	if M.config.api_key and M.config.analysis_interval > 0 then
		timer:start(M.config.analysis_interval * 1000, M.config.analysis_interval * 1000, function()
			vim.schedule(analyze_command_history)
		end)
	end
end

local function stop_periodic_analysis()
	timer:stop()
end

function M.setup(opts)
	-- Merge user config with defaults
	M.config = vim.tbl_deep_extend("force", M.config, opts or {})

	-- Load saved instructions on setup
	load_instructions()

	vim.api.nvim_create_user_command("BackseatInstructions", function()
		-- Create a new buffer
		local buf = vim.api.nvim_create_buf(false, true)

		-- Set buffer options
		vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
		vim.api.nvim_buf_set_option(buf, "modifiable", true)
		vim.api.nvim_buf_set_option(buf, "buftype", "acwrite")

		-- Default instructions template (not saved)
		local default_template = {
			"# Backseat Instructions",
			"",
			"Enter instructions below for habits you want to avoid/replace/improve in your Neovim usage.",
			"Only the text you write below the guidelines will be sent to the AI.",
			"",
			"## Guidelines (not included in prompt):",
			"- List specific habits or commands you want to avoid",
			"- Describe better alternatives you want to use instead",
			"- Focus on vim navigation patterns and efficiency",
			"",
			"## Your Instructions (write below this line):",
			"---",
		}

		-- Build buffer content
		local content = {}
		for _, line in ipairs(default_template) do
			table.insert(content, line)
		end

		-- If we have saved instructions, append them
		if M.instructions ~= "" then
			local instruction_lines = vim.split(M.instructions, "\n")
			for _, line in ipairs(instruction_lines) do
				table.insert(content, line)
			end
		end
		-- Set the content
		vim.api.nvim_buf_set_lines(buf, 0, -1, false, content)

		-- Open in a new window
		vim.cmd("split")
		local win = vim.api.nvim_get_current_win()
		vim.api.nvim_win_set_buf(win, buf)

		-- Set window height
		vim.api.nvim_win_set_height(win, 15)

		-- Name the buffer
		vim.api.nvim_buf_set_name(buf, "Backseat Instructions")

		-- Set filetype for syntax highlighting
		-- vim.api.nvim_buf_set_option(buf, "filetype", "markdown")
		vim.api.nvim_set_option_value("filetype", "markdown", {})

		-- Move cursor to the instructions area
		local offset = M.instructions ~= "" and 1 or 0
		vim.api.nvim_win_set_cursor(win, { #default_template + offset, 0 })

		-- Set up autocmd to save instructions when leaving buffer
		vim.api.nvim_create_autocmd({ "BufWinLeave", "BufUnload" }, {
			buffer = buf,
			callback = function()
				local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
				-- Find the separator line and only save content after it
				local start_idx = 0
				for i, line in ipairs(lines) do
					if line == "---" then
						start_idx = i + 1
						break
					end
				end

				-- Extract only user instructions
				local user_instructions = {}
				for i = start_idx, #lines do
					if lines[i] then
						table.insert(user_instructions, lines[i])
					end
				end

				M.instructions = table.concat(user_instructions, "\n")
				save_instructions() -- Save to file when leaving buffer
			end,
		})

		-- Handle write commands with BufWriteCmd since we set buftype=acwrite
		vim.api.nvim_create_autocmd("BufWriteCmd", {
			buffer = buf,
			callback = function()
				local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
				-- Find the separator line and only save content after it
				local start_idx = 0
				for i, line in ipairs(lines) do
					if line == "---" then
						start_idx = i + 1
						break
					end
				end

				-- Extract only user instructions
				local user_instructions = {}
				for i = start_idx, #lines do
					if lines[i] then
						table.insert(user_instructions, lines[i])
					end
				end

				M.instructions = table.concat(user_instructions, "\n")
				save_instructions() -- Save to file when writing
				vim.api.nvim_set_option_value("modified", false, {})
				print("Backseat instructions saved!")
			end,
		})
	end, {})

	create_command_monitor()

	vim.api.nvim_create_user_command("ShowCommandHistory", function()
		for i, cmd in ipairs(M.get_recent_commands(10)) do
			print(string.format("%d: %s", i, cmd))
		end
	end, {})

	vim.api.nvim_create_user_command("BackseatAnalyze", function()
		analyze_command_history()
	end, {})

	vim.api.nvim_create_user_command("BackseatStartAnalysis", function()
		start_periodic_analysis()
		vim.notify("Backseat: Started periodic analysis", vim.log.levels.INFO)
	end, {})

	vim.api.nvim_create_user_command("BackseatStopAnalysis", function()
		stop_periodic_analysis()
		vim.notify("Backseat: Stopped periodic analysis", vim.log.levels.INFO)
	end, {})

	-- Start periodic analysis if configured
	if M.config.api_key then
		start_periodic_analysis()
	end
end

function M.get_recent_commands(limit)
	limit = limit or 10
	local recent = {}
	local start_idx = math.max(1, #M.command_history - limit + 1)
	for i = start_idx, #M.command_history do
		table.insert(recent, M.command_history[i])
	end
	return recent
end

return M
