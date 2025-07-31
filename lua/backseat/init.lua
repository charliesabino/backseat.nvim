local M = {}

M.command_history = {}

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
	vim.api.nvim_create_user_command("Blindspots", function() end, {})

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

return M
