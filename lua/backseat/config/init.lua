local M = {}

M.defaults = {
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

M.current = vim.deepcopy(M.defaults)

function M.setup(opts)
	M.current = vim.tbl_deep_extend("force", M.defaults, opts or {})
	return M.current
end

function M.get()
	return M.current
end

return M