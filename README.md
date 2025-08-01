# backseat.nvim

An AI-powered Neovim plugin that monitors your Vim habits and provides real-time feedback to help improve your workflow efficiency.

## Table of Contents

- [Features](#features)
- [Requirements](#requirements)
- [Installation](#installation)
- [Configuration](#configuration)
  - [API Key](#api-key)
  - [Options](#options)
- [Usage](#usage)
  - [Setting Instructions](#setting-instructions)
  - [Commands](#commands)
- [How It Works](#how-it-works)
- [Example Instructions](#example-instructions)
- [Privacy](#privacy)
- [License](#license)

## Features

- **Real-time command monitoring**: Tracks your normal mode commands and patterns
- **AI-powered analysis**: Uses Claude AI to analyze your habits against your defined instructions
- **Customizable instructions**: Define your own rules for what habits to avoid or improve
- **Periodic feedback**: Automatically analyzes your command history at configurable intervals
- **Persistent instructions**: Your custom instructions are saved and loaded automatically

## Requirements

- Neovim 0.7+
- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim) for HTTP requests
- Anthropic API key

## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
    "charliesabino/backseat.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
        require("backseat").setup({
            -- Your Anthropic API key
            api_key = vim.env.ANTHROPIC_API_KEY or "your-api-key-here",
            
            -- Analysis interval in seconds (default: 15)
            analysis_interval = 15,
            
            -- Maximum command history size to prevent memory issues
            max_history_size = 50,
            
            -- Anthropic API endpoint (usually doesn't need changing)
            endpoint = "https://api.anthropic.com/v1/messages",
            
            -- Model to use for analysis (default: claude-3-5-haiku for efficiency)
            model = "claude-3-5-haiku-latest",
            
            -- Enable/disable normal mode monitoring
            enable_monitoring = true,
        })
    end,
}
```

## Configuration

### API Key

Set your Anthropic API key either in your config or as an environment variable:

```bash
export ANTHROPIC_API_KEY="your-api-key-here"
```

### Options

| Option | Default | Description |
|--------|---------|-------------|
| `api_key` | `nil` | Your Anthropic API key (required) |
| `analysis_interval` | `15` | Seconds between automatic analysis |
| `max_history_size` | `50` | Maximum commands to store in history |
| `endpoint` | `"https://api.anthropic.com/v1/messages"` | Anthropic API endpoint |
| `model` | `"claude-3-5-haiku-latest"` | Claude model to use |
| `enable_monitoring` | `true` | Enable/disable command monitoring |

## Usage

### Setting Instructions

Define what habits you want to improve:

```vim
:BackseatInstructions
```

This opens a buffer where you can write instructions like:
- "Use `w` and `b` instead of holding `h` and `l`"
- "Prefer `f` and `t` motions over repeated `w`"
- "Use `ci{` instead of `di{i`"

Your instructions are automatically saved and persist between sessions.

### Commands

| Command | Description |
|---------|-------------|
| `:BackseatInstructions` | Open/edit your custom instructions |
| `:BackseatAnalyze` | Manually trigger analysis of recent commands |
| `:BackseatStartAnalysis` | Start periodic automatic analysis |
| `:BackseatStopAnalysis` | Stop periodic automatic analysis |
| `:ShowCommandHistory` | Display recent command history |

## How It Works

1. The plugin monitors your normal mode keystrokes and builds a command history
2. Every `analysis_interval` seconds, it sends your recent commands to Claude
3. Claude analyzes the commands against your defined instructions
4. If you're deviating from your desired habits, you get a notification with terse feedback
5. If your commands align with your instructions, no notification is shown

## Example Instructions

```
Avoid using arrow keys, use hjkl instead
Use text objects (iw, i", i{) instead of visual mode selection
Prefer % for matching brackets over manual navigation
Use . to repeat commands instead of retyping
Avoid excessive use of x for deletion, use d with motions
```

## Privacy

- Only your command keystrokes and custom instructions are sent to the API
- No file contents or sensitive data are transmitted
- Commands are processed in batches and cleared after analysis

## License

MIT