local M = {}

M.command_history = {}
M.instructions = "" -- Store user instructions

-- Get the data directory for persisting instructions
local data_dir = vim.fn.stdpath("data") .. "/backseat"
local instructions_file = data_dir .. "/instructions.txt"

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
	vim.on_key(function(key)
		if vim.fn.mode() == "n" then
			table.insert(M.command_history, {
				command = vim.fn.keytrans(key),
				timestamp = os.time(),
				mode = "n",
			})
		end
	end)
end

function M.setup()
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
		for i, entry in ipairs(M.get_recent_commands(10)) do
			print(string.format("%d: [%s] %s", i, entry.mode, entry.command))
		end
	end, {})
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

function M.get_instructions()
	return M.instructions
end

return M
