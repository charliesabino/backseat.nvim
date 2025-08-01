local M = {}

M.command_history = {}
M.instructions = "" -- Store user instructions

M.config = {
	api_key = nil,
	analysis_interval = 300, -- 5 minutes in seconds
	max_history_size = 10000,
	endpoint = "https://api.anthropic.com/v1/messages",
	model = "claude-3-5-haiku-latest",
	enable_monitoring = true, -- Allow disabling key monitoring for performance
}

-- Get the data directory for persisting instructions
local data_dir = vim.fn.stdpath("data") .. "/backseat"
local instructions_file = data_dir .. "/instructions.txt"
local timer = vim.loop.new_timer()

-- Cache for UTF8 validation to avoid repeated processing
local utf8_cache = setmetatable({}, { __mode = "k" })

function fixUTF8(s)
	-- Check cache first
	local cached = utf8_cache[s]
	if cached then
		return cached[1], cached[2]
	end

	-- For small strings, just filter out control characters
	if #s < 50 then
		local clean = s:gsub("[%c%z]", "")
		utf8_cache[s] = { clean, {} }
		return clean, {}
	end

	-- For larger strings, do full UTF8 validation
	local p, len, invalid = 1, #s, {}
	while p <= len do
		if p == s:find("[%z\1-\127]", p) then
			p = p + 1
		elseif p == s:find("[\194-\223][\128-\191]", p) then
			p = p + 2
		elseif
			p == s:find("\224[\160-\191][\128-\191]", p)
			or p == s:find("[\225-\236][\128-\191][\128-\191]", p)
			or p == s:find("\237[\128-\159][\128-\191]", p)
			or p == s:find("[\238-\239][\128-\191][\128-\191]", p)
		then
			p = p + 3
		elseif
			p == s:find("\240[\144-\191][\128-\191][\128-\191]", p)
			or p == s:find("[\241-\243][\128-\191][\128-\191][\128-\191]", p)
			or p == s:find("\244[\128-\143][\128-\191][\128-\191]", p)
		then
			p = p + 4
		else
			s = s:sub(1, p - 1) .. s:sub(p + 1)
			table.insert(invalid, p)
		end
	end

	-- Cache the result
	utf8_cache[s] = { s, invalid }
	return s, invalid
end

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
		max_tokens = 1024,
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
				if data and data.content and data.content[1] and data.content[1] ~= "No feedback." then
					vim.schedule(function()
						vim.notify("Backseat Analysis:\n" .. data.content[1].text, vim.log.levels.INFO)
					end)
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
	local recent_commands = M.get_recent_commands(50)
	if #recent_commands == 0 then
		return
	end

	local command_list = {}
	for _, cmd in ipairs(recent_commands) do
		-- Filter out non-printable characters and ensure valid UTF-8
		-- local clean_command = cmd:gsub("[%c%z]", ""):gsub("[\194-\244][\128-\191]*", "")
		-- local clean_command = fixUTF8(cmd)
		if clean_command ~= "" then
			-- print(clean_command)
			table.insert(command_list, clean_command)
		end
	end

	local prompt = string.format(
		[[You are a Neovim expert analyzing command patterns. Here are the user's instructions:

%s

Here are the recent commands:
%s

Provide a brief analysis of inefficiencies or suggestions for improvement based on the patterns you see.

Be incredibly terse.

If the user provided instructions, then only make recommendations based on their instructions.

If you do not have any feedback, then respond with only the words "No feedback".
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

	vim.api.nvim_create_user_command("Blindspots", function()
		-- Create a new buffer
		local buf = vim.api.nvim_create_buf(false, true)

		-- Set buffer options
		vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
		vim.api.nvim_buf_set_option(buf, "modifiable", true)
		vim.api.nvim_buf_set_option(buf, "buftype", "acwrite")

		-- Default instructions
		local default_instructions = {
			"# Blindspots Instructions",
			"",
			"Enter your custom instructions below. These will guide the plugin's behavior.",
			"",
			"## Guidelines:",
			"- Be specific about what you want to track or improve",
			"- Focus on vim navigation patterns and efficiency",
			"- Consider your common workflows and pain points",
			"",
			"## Your Instructions:",
			"",
			"",
		}

		-- If we have saved instructions, show them instead
		local content = default_instructions
		if M.instructions ~= "" then
			content = vim.split(M.instructions, "\n")
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
		vim.api.nvim_buf_set_name(buf, "Blindspots Instructions")

		-- Set filetype for syntax highlighting
		-- vim.api.nvim_buf_set_option(buf, "filetype", "markdown")
		vim.api.nvim_set_option_value("filetype", "markdown", {})

		-- Move cursor to the instructions area
		if M.instructions == "" then
			vim.api.nvim_win_set_cursor(win, { #default_instructions, 0 })
		end

		-- Set up autocmd to save instructions when leaving buffer
		vim.api.nvim_create_autocmd({ "BufWinLeave", "BufUnload" }, {
			buffer = buf,
			callback = function()
				local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
				M.instructions = table.concat(lines, "\n")
				save_instructions() -- Save to file when leaving buffer
			end,
		})

		-- Handle write commands with BufWriteCmd since we set buftype=acwrite
		vim.api.nvim_create_autocmd("BufWriteCmd", {
			buffer = buf,
			callback = function()
				local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
				M.instructions = table.concat(lines, "\n")
				save_instructions() -- Save to file when writing
				vim.api.nvim_set_option_value("modified", false, {})
				print("Blindspots instructions saved!")
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
