# Ollama Setup for Backseat.nvim

## Installation

1. Install Ollama from <https://ollama.com>
2. Pull a model (e.g., `ollama pull llama3.2`)

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

## Usage

Same as other models - set instructions with `:BackseatInstructions` and select model with `:BackseatSelectModel`

