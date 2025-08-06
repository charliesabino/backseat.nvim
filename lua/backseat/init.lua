local M = {}

M.command_history = {}
M.instructions = "" -- Store user instructions

local DEFAULT_MODELS = {
	"claude-3-5-haiku-latest",
	"gemini-2.5-flash",
	"gemini-2.5-flash-lite",
	"gemini-2.0-flash",
}

local MODELS = vim.deepcopy(DEFAULT_MODELS)

M.config = {
	anthropic_api_key = vim.env.ANTHROPIC_API_KEY,
	gemini_api_key = vim.env.GEMINI_API_KEY,
	ollama_host = vim.env.OLLAMA_HOST or "http://localhost:11434",
	analysis_interval = 15,
	max_history_size = 50,
	max_tokens = 128,
	endpoint = "https://api.anthropic.com/v1/messages",
	model = "gemini-2.0-flash",
	enable_monitoring = true,
}

-- Get the data directory for persisting instructions
local data_dir = vim.fn.stdpath("data") .. "/backseat"
local instructions_file = data_dir .. "/instructions.txt"
local timer = vim.loop.new_timer()

-- Fetch available Ollama models
local function fetch_ollama_models()
	local ok, curl = pcall(require, "plenary.curl")
	if not ok then
		return
	end

	local url = (M.config.ollama_host or "http://localhost:11434") .. "/api/tags"

	curl.get(url, {
		timeout = 5000,
		callback = function(response)
			if response.status == 200 then
				local success, data = pcall(vim.json.decode, response.body)
				if success and data and data.models then
					vim.schedule(function()
						-- Reset to default models first
						MODELS = vim.deepcopy(DEFAULT_MODELS)
						-- Add Ollama models
						for _, model in ipairs(data.models) do
							if model.name then
								-- Remove :latest suffix if present for cleaner display
								local model_name = model.name:gsub(":latest$", "")
								table.insert(MODELS, model_name)
							end
						end
					end)
				end
			end
		end,
	})
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

local function normalize_key(raw)
	-- Normalize to termcodes and human-readable
	local rt = vim.api.nvim_replace_termcodes(raw, true, true, true)
	local tok = vim.fn.keytrans(rt)

	-- Map actual leader chars to <Leader>/<LocalLeader>
	local leader = vim.g.mapleader or "\\"
	local localleader = vim.g.maplocalleader or "\\"
	if tok == leader then
		tok = "<Leader>"
	end
	if tok == localleader then
		tok = "<LocalLeader>"
	end

	-- If the token itself is <...>, escape any *inner* '<' to <lt>
	-- e.g. "<t_<fd>g>" -> "<t_<lt>fd>g>"
	tok = tok:gsub("^<([^>]+)>$", function(inner)
		inner = inner:gsub("<", "<lt>")
		return "<" .. inner .. ">"
	end)

	-- Drop NUL/C0 controls (Anthropic rejects null bytes)
	tok = tok:gsub("[%z\1-\31]", "")

	return tok
end

local function create_command_monitor()
	vim.on_key(function(key)
		if not M.config.enable_monitoring or vim.fn.mode() ~= "n" then
			return
		end

		local translated = normalize_key(key)

		if translated:match("^<[^>]+>$") or translated:match("^[^<]$") then
			table.insert(M.command_history, translated)
		end

		if #M.command_history > M.config.max_history_size then
			table.remove(M.command_history, 1)
		end
	end)
end

local function make_google_request(prompt)
	if not M.config.gemini_api_key then
		vim.notify("Backseat: Gemini API key not configured", vim.log.levels.ERROR)
		return
	end

	local ok, curl = pcall(require, "plenary.curl")
	if not ok then
		vim.notify("Backseat: plenary.nvim is required for API requests", vim.log.levels.ERROR)
		return
	end

	local url =
		string.format("https://generativelanguage.googleapis.com/v1beta/models/%s:generateContent", M.config.model)

	local headers = {
		["content-type"] = "application/json",
		["x-goog-api-key"] = M.config.gemini_api_key,
	}

	local body = vim.json.encode({
		contents = {
			{
				parts = {
					{
						text = prompt,
					},
				},
			},
		},
		generationConfig = {
			maxOutputTokens = M.config.max_tokens,
			temperature = 0.1,
		},
	})

	url = curl.post(url, {
		headers = headers,
		body = body,
		callback = function(response)
			if response.status == 200 then
				local data = vim.json.decode(response.body)
				if
					data
					and data.candidates
					and data.candidates[1]
					and data.candidates[1].content
					and data.candidates[1].content.parts
					and data.candidates[1].content.parts[1]
				then
					local text = data.candidates[1].content.parts[1].text
					if not string.find(text or "", "No feedback") then
						vim.schedule(function()
							vim.notify(M.config.model .. " Analysis:\n" .. text, vim.log.levels.INFO)
						end)
					end
				else
					vim.schedule(function()
						vim.notify("Backseat: API request failed - " .. response.status, vim.log.levels.ERROR)
					end)
				end
			end
		end,
	})
end

local function make_ollama_request(prompt)
	local ok, curl = pcall(require, "plenary.curl")
	if not ok then
		vim.notify("Backseat: plenary.nvim is required for API requests", vim.log.levels.ERROR)
		return
	end

	local url = M.config.ollama_host .. "/api/generate"

	local headers = {
		["content-type"] = "application/json",
	}

	local body = vim.json.encode({
		model = M.config.model,
		prompt = prompt,
		stream = false,
		options = {
			num_predict = M.config.max_tokens,
			temperature = 0.1,
		},
	})

	curl.post(url, {
		headers = headers,
		body = body,
		timeout = 30000,
		callback = function(response)
			if response.status == 200 then
				local data = vim.json.decode(response.body)
				if data and data.response then
					local text = data.response
					if not string.find(text or "", "No feedback") then
						vim.schedule(function()
							vim.notify(M.config.model .. " Analysis:\n" .. text, vim.log.levels.INFO)
						end)
					end
				end
			else
				vim.schedule(function()
					local error_msg = "Backseat: Ollama request failed - " .. response.status
					if response.body then
						local ok, err_data = pcall(vim.json.decode, response.body)
						if ok and err_data.error then
							error_msg = error_msg .. " (" .. err_data.error .. ")"
						end
					end
					vim.notify(error_msg, vim.log.levels.ERROR)
				end)
			end
		end,
	})
end

local function make_anthropic_request(prompt)
	if not M.config.anthropic_api_key then
		vim.notify("Backseat: API key not configured", vim.log.levels.ERROR)
		return
	end

	local ok, curl = pcall(require, "plenary.curl")
	if not ok then
		vim.notify("Backseat: plenary.nvim is required for API requests", vim.log.levels.ERROR)
		return
	end

	local headers = {
		["x-api-key"] = M.config.anthropic_api_key,
		["anthropic-version"] = "2023-06-01",
		["content-type"] = "application/json",
	}

	local body = vim.json.encode({
		model = M.config.model,
		max_tokens = M.config.max_tokens,
		messages = {
			{
				role = "user",
				content = {
					{
						type = "text",
						text = prompt,
					},
				},
			},
		},
	})

	local url = "https://api.anthropic.com/v1/messages"

	curl.post(url, {
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
						vim.notify(M.config.model .. " Analysis:\n" .. data.content[1].text, vim.log.levels.INFO)
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
	local recent_commands = M.get_recent_commands(#M.command_history)

	if #recent_commands == 0 or M.instructions == "" then
		return
	end

	local command_list = {}
	for _, cmd in ipairs(recent_commands) do
		local clean_command = cmd:gsub("[%c%z]", ""):gsub("[\194-\244][\128-\191]*", "")
		if clean_command ~= "" then
			table.insert(command_list, clean_command)
		end
	end

	local prompt = string.format(
		[[You are a Neovim expert. Your task is to analyze a list of recent commands and provide feedback based *only* on the user's instructions.

<instructions>
%s
</instructions>

<commands>
%s
</commands>

Analyze the commands against the instructions.
- Provide feedback only for deviations from the instructions.
- All feedback must be incredibly terse. As much as possible, respond along the lines of "Use X instead of Y." with nothing else appended. Your response should fit in a small text box if possible.
- If there are no deviations or no feedback is necessary, respond with the exact phrase "No feedback" and nothing else.
- Do NOT provide feedback unless they violate the instructions.
- Provide feedback ONLY related to the violated instruction(s).
]],
		M.instructions,
		table.concat(command_list, "\n")
	)

	if M.config.model:match("^gemini") then
		make_google_request(prompt)
	elseif M.config.model:match("^claude") then
		make_anthropic_request(prompt)
	else
		-- Assume Ollama for all other models
		make_ollama_request(prompt)
	end

	M.command_history = {}
end

local function start_periodic_analysis()
	if
		(M.config.anthropic_api_key or M.config.gemini_api_key or M.config.ollama_host)
		and M.config.analysis_interval > 0
	then
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

	-- Fetch Ollama models if available
	if M.config.ollama_host then
		fetch_ollama_models()
	end

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

	vim.api.nvim_create_user_command("BackseatRefreshModels", function()
		if M.config.ollama_host then
			fetch_ollama_models()
			vim.notify("Backseat: Refreshing Ollama models...", vim.log.levels.INFO)
		else
			vim.notify("Backseat: Ollama host not configured", vim.log.levels.WARN)
		end
	end, {})

	vim.api.nvim_create_user_command("BackseatSelectModel", function()
		-- Refresh Ollama models before showing selection
		if M.config.ollama_host then
			fetch_ollama_models()
		end
		-- Small delay to allow models to be fetched
		vim.defer_fn(function()
			vim.ui.select(MODELS, {
				prompt = "Select model:",
				format_item = function(item)
					-- Add indicators for model types and current selection
					local suffix = ""
					if item:match("^claude") then
						suffix = " (Anthropic)"
					elseif item:match("^gemini") then
						suffix = " (Google)"
					else
						suffix = " (Ollama)"
					end

					-- Add indicator for current model
					if item == M.config.model then
						return "► " .. item .. suffix .. " [current]"
					else
						return "  " .. item .. suffix
					end
				end,
			}, function(choice)
				if choice then
					M.config.model = choice
					vim.notify("Backseat: Model changed to " .. choice, vim.log.levels.INFO)
				end
			end)
		end, 100)
	end, {})

	-- Start periodic analysis if configured
	if M.config.anthropic_api_key or M.config.gemini_api_key or M.config.ollama_host then
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
