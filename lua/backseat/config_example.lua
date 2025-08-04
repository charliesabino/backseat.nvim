return {
	"charliesabino/backseat.nvim",
	config = function()
		require("backseat").setup({
			-- Your Anthropic API key
			anthropic_api_key = vim.env.ANTHROPIC_API_KEY or "your-api-key-here",

			-- Analysis interval in seconds (default: 15)
			analysis_interval = 15,

			-- Maximum command history size to prevent memory issues
			max_history_size = 50,

			-- Anthropic API endpoint (usually doesn't need changing)
			endpoint = "https://api.anthropic.com/v1/messages",

			-- Model to use for analysis (default: claude-3-5-haiku for efficiency)
			model = "claude-3-5-haiku-latest",

			-- Enable/Disable normal mode monitoring
			enable_monitoring = true,
		})
	end,
}
