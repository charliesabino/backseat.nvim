local M = {}

function M.setup()
	vim.api.nvim_create_user_command("Blindspots", function()
		print("Hello")
	end, {})
end

return M
