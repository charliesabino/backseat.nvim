return {
	"charliesabino/backseat.nvim",
	config = function()
		require("backseat").setup({
			-- Your Anthropic API key
			anthropic_api_key = vim.env.ANTHROPIC_API_KEY or "your-api-key-here",

			-- Your Gemini API key
			gemini_api_key = vim.env.GEMINI_API_KEY or "your-api-key-here",

			-- Ollama host for local models (optional)
			ollama_host = vim.env.OLLAMA_HOST or "http://localhost:11434",

			-- Analysis interval in seconds (default: 15)
			analysis_interval = 15,

			-- Maximum command history size to prevent memory issues
			max_history_size = 50,

			-- Model to use for analysis (default: gemini-2.0-flash, see https://sanand0.github.io/llmpricing/)
			model = "gemini-2.0-flash",

			-- Enable/Disable normal mode monitoring
			enable_monitoring = true,
		})
	end,
}
