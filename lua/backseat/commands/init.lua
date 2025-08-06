local M = {}

local api = require("backseat.api")
local monitor = require("backseat.monitor")
local persistence = require("backseat.persistence")
local config = require("backseat.config")

local timer = vim.loop.new_timer()

local function analyze_command_history()
	local cfg = config.get()
	local recent_commands = monitor.get_recent_commands(#monitor.command_history)
	local instructions = persistence.get_instructions()

	if #recent_commands == 0 or instructions == "" then
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
		instructions,
		table.concat(command_list, "\n")
	)

	api.make_request(prompt, cfg)
	monitor.clear_history()
end

function M.start_periodic_analysis()
	local cfg = config.get()
	if
		(cfg.anthropic_api_key or cfg.gemini_api_key or cfg.ollama_host)
		and cfg.analysis_interval > 0
	then
		timer:start(cfg.analysis_interval * 1000, cfg.analysis_interval * 1000, function()
			vim.schedule(analyze_command_history)
		end)
	end
end

function M.stop_periodic_analysis()
	timer:stop()
end

function M.setup_commands()
	vim.api.nvim_create_user_command("BackseatReplacementRules", function()
		local buf = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
		vim.api.nvim_buf_set_option(buf, "modifiable", true)
		vim.api.nvim_buf_set_option(buf, "buftype", "acwrite")

		local default_template = {
			"# Backseat Replacement Rules",
			"",
			"Enter replacement rules below in the format: replacement,original",
			"For example: 'go,gg' means suggest 'go' when user types 'gg'",
			"",
			"## Guidelines (not included in rules):",
			"- One rule per line",
			"- Format: replacement,original",
			"- The original pattern is matched at the end of commands",
			"- Example: 'w,<Right>' suggests 'w' instead of arrow keys",
			"",
			"## Your Rules (write below this line):",
			"---",
		}

		local content = {}
		for _, line in ipairs(default_template) do
			table.insert(content, line)
		end

		local rules = persistence.get_replacement_rules()
		for original, replacement in pairs(rules) do
			table.insert(content, replacement .. "," .. original)
		end

		vim.api.nvim_buf_set_lines(buf, 0, -1, false, content)

		vim.cmd("split")
		local win = vim.api.nvim_get_current_win()
		vim.api.nvim_win_set_buf(win, buf)
		vim.api.nvim_win_set_height(win, 15)
		vim.api.nvim_buf_set_name(buf, "Backseat Replacement Rules")
		vim.api.nvim_set_option_value("filetype", "markdown", {})
		vim.api.nvim_win_set_cursor(win, { #default_template, 0 })

		local function save_rules_from_buffer()
			local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
			local start_idx = 0
			for i, line in ipairs(lines) do
				if line == "---" then
					start_idx = i + 1
					break
				end
			end

			local new_rules = {}
			for i = start_idx, #lines do
				if lines[i] and lines[i] ~= "" then
					local replacement, original = lines[i]:match("^([^,]+),(.+)$")
					if replacement and original then
						new_rules[original] = replacement
					end
				end
			end

			persistence.save_replacement_rules(new_rules)
			monitor.set_replacement_rules(new_rules)
		end

		vim.api.nvim_create_autocmd({ "BufWinLeave", "BufUnload" }, {
			buffer = buf,
			callback = save_rules_from_buffer,
		})

		vim.api.nvim_create_autocmd("BufWriteCmd", {
			buffer = buf,
			callback = function()
				save_rules_from_buffer()
				vim.api.nvim_set_option_value("modified", false, {})
				print("Backseat replacement rules saved!")
			end,
		})
	end, {})

	vim.api.nvim_create_user_command("BackseatModelInstructions", function()
		local buf = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
		vim.api.nvim_buf_set_option(buf, "modifiable", true)
		vim.api.nvim_buf_set_option(buf, "buftype", "acwrite")

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

		local content = {}
		for _, line in ipairs(default_template) do
			table.insert(content, line)
		end

		local instructions = persistence.get_instructions()
		if instructions ~= "" then
			local instruction_lines = vim.split(instructions, "\n")
			for _, line in ipairs(instruction_lines) do
				table.insert(content, line)
			end
		end

		vim.api.nvim_buf_set_lines(buf, 0, -1, false, content)

		vim.cmd("split")
		local win = vim.api.nvim_get_current_win()
		vim.api.nvim_win_set_buf(win, buf)
		vim.api.nvim_win_set_height(win, 15)
		vim.api.nvim_buf_set_name(buf, "Backseat Instructions")
		vim.api.nvim_set_option_value("filetype", "markdown", {})
		local offset = instructions ~= "" and 1 or 0
		vim.api.nvim_win_set_cursor(win, { #default_template + offset, 0 })

		local function save_instructions_from_buffer()
			local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
			local start_idx = 0
			for i, line in ipairs(lines) do
				if line == "---" then
					start_idx = i + 1
					break
				end
			end

			local user_instructions = {}
			for i = start_idx, #lines do
				if lines[i] then
					table.insert(user_instructions, lines[i])
				end
			end

			persistence.save_instructions(table.concat(user_instructions, "\n"))
		end

		vim.api.nvim_create_autocmd({ "BufWinLeave", "BufUnload" }, {
			buffer = buf,
			callback = save_instructions_from_buffer,
		})

		vim.api.nvim_create_autocmd("BufWriteCmd", {
			buffer = buf,
			callback = function()
				save_instructions_from_buffer()
				vim.api.nvim_set_option_value("modified", false, {})
				print("Backseat instructions saved!")
			end,
		})
	end, {})

	vim.api.nvim_create_user_command("ShowCommandHistory", function()
		for i, cmd in ipairs(monitor.get_recent_commands(10)) do
			print(string.format("%d: %s", i, cmd))
		end
	end, {})

	vim.api.nvim_create_user_command("BackseatAnalyze", function()
		analyze_command_history()
	end, {})

	vim.api.nvim_create_user_command("BackseatStartAnalysis", function()
		M.start_periodic_analysis()
		vim.notify("Backseat: Started periodic analysis", vim.log.levels.INFO)
	end, {})

	vim.api.nvim_create_user_command("BackseatStopAnalysis", function()
		M.stop_periodic_analysis()
		vim.notify("Backseat: Stopped periodic analysis", vim.log.levels.INFO)
	end, {})

	vim.api.nvim_create_user_command("BackseatRefreshModels", function()
		local cfg = config.get()
		if cfg.ollama_host then
			api.fetch_ollama_models(cfg)
			vim.notify("Backseat: Refreshing Ollama models...", vim.log.levels.INFO)
		else
			vim.notify("Backseat: Ollama host not configured", vim.log.levels.WARN)
		end
	end, {})

	vim.api.nvim_create_user_command("BackseatSelectModel", function()
		local cfg = config.get()
		if cfg.ollama_host then
			api.fetch_ollama_models(cfg)
		end
		vim.defer_fn(function()
			vim.ui.select(api.get_models(), {
				prompt = "Select model:",
				format_item = function(item)
					local suffix = ""
					if item:match("^claude") then
						suffix = " (Anthropic)"
					elseif item:match("^gemini") then
						suffix = " (Google)"
					else
						suffix = " (Ollama)"
					end

					if item == cfg.model then
						return "► " .. item .. suffix .. " [current]"
					else
						return "  " .. item .. suffix
					end
				end,
			}, function(choice)
				if choice then
					cfg.model = choice
					vim.notify("Backseat: Model changed to " .. choice, vim.log.levels.INFO)
				end
			end)
		end, 100)
	end, {})
end

return M