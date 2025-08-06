# Ollama Setup for Backseat.nvim

## Installation

1. Install Ollama from <https://ollama.com>
2. Pull a model (e.g., `ollama pull llama3.2`)
3. Ensure Ollama is running (`ollama serve`)

## Configuration

Add to your Neovim config:

```lua
require('backseat').setup({
  ollama_host = "http://localhost:11434", -- default
  model = "llama3.2", -- or any installed Ollama model
  -- other options...
})
```

## Environment Variables

Set `OLLAMA_HOST` to use a remote Ollama instance:

```bash
export OLLAMA_HOST="http://remote-server:11434"
```

## Dynamic Model Detection

The plugin automatically detects your installed Ollama models! When you:
- Run `:BackseatSelectModel` - it fetches and displays all available Ollama models
- Run `:BackseatRefreshModels` - manually refresh the Ollama models list
- Start the plugin - it automatically fetches models if `ollama_host` is configured

Models are shown with indicators:
- `(Anthropic)` - Claude models
- `(Google)` - Gemini models  
- `(Ollama)` - Local Ollama models

## Usage

1. Set instructions with `:BackseatInstructions`
2. Select a model with `:BackseatSelectModel` (shows all installed Ollama models)
3. Start analysis with `:BackseatStartAnalysis`

## Troubleshooting

If models don't appear:
- Ensure Ollama is running: `ollama serve`
- Check available models: `ollama list`
- Refresh model list: `:BackseatRefreshModels`
