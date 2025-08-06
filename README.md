# backseat.nvim

An AI-powered Neovim plugin that monitors your Vim habits and provides real-time feedback to help improve your workflow efficiency.

<https://github.com/user-attachments/assets/ec19bc33-ade4-4500-be2c-a83851d7c72d>

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
- [Cost](#cost)
- [Privacy](#privacy)
- [License](#license)

## Features

- **Real-time command monitoring**: Tracks your normal mode commands and patterns
- **AI-powered analysis**: Uses Claude AI to analyze your habits against your defined instructions
- **Customizable instructions**: Define your own rules for what habits to avoid or improve
- **Instant replacement rules**: Get immediate feedback for simple command substitutions
- **Periodic feedback**: Automatically analyzes your command history at configurable intervals
- **Persistent settings**: Your custom instructions and replacement rules are saved and loaded automatically

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

Backseat.nvim offers two ways to define improvement rules:

#### 1. Replacement Rules (Simple Substitutions)

For straightforward command substitutions, use replacement rules:

```vim
:BackseatReplacementRules
```

This opens a buffer where you can define simple key-value pairs:
- `go,gg` - suggests using `go` instead of `gg`
- `w,<Right>` - suggests using `w` instead of arrow keys
- `0,<Home>` - suggests using `0` instead of Home key

Replacement rules provide **instant feedback** as you type, making them ideal for breaking specific bad habits.

#### 2. Model Instructions (Complex Patterns)

For more complex patterns and context-aware feedback, use model instructions:

```vim
:BackseatModelInstructions
```

This opens a buffer where you can write natural language instructions like:
- "Use `w` and `b` instead of holding `h` and `l`"
- "Prefer `f` and `t` motions over repeated `w`"
- "Use `ci{` instead of `di{i`"
- "Avoid excessive visual mode for simple operations"

Model instructions are analyzed periodically by AI and can understand complex patterns and context.

Both settings are automatically saved and persist between sessions.

### Commands

| Command | Description |
|---------|-------------|
| `:BackseatReplacementRules` | Open/edit simple replacement rules (instant feedback) |
| `:BackseatModelInstructions` | Open/edit AI-analyzed instructions (periodic feedback) |
| `:BackseatAnalyze` | Manually trigger AI analysis of recent commands |
| `:BackseatStartAnalysis` | Start periodic automatic analysis |
| `:BackseatStopAnalysis` | Stop periodic automatic analysis |
| `:ShowCommandHistory` | Display recent command history |
| `:BackseatSelectModel` | Select which AI model to use |
| `:BackseatRefreshModels` | Refresh available Ollama models |

## How It Works

1. The plugin monitors your normal mode keystrokes and builds a command history
2. **Instant feedback**: Replacement rules are checked on every keystroke for immediate notifications
3. **Periodic analysis**: Every `analysis_interval` seconds, recent commands are sent to the AI model
4. The AI analyzes commands against your model instructions for complex pattern matching
5. If you're deviating from your desired habits, you get a notification with terse feedback
6. If your commands align with your instructions, no notification is shown

## Example Instructions

### Replacement Rules (in :BackseatReplacementRules)
```
w,<Right>
b,<Left>
gg,<Home>
G,<End>
0,^
ge,be
```

### Model Instructions (in :BackseatModelInstructions)
```
Avoid using arrow keys, use hjkl instead
Use text objects (iw, i", i{) instead of visual mode selection
Prefer % for matching brackets over manual navigation
Use . to repeat commands instead of retyping
Avoid excessive use of x for deletion, use d with motions
When navigating between words, prefer f/F/t/T over multiple w/b commands
```

## Cost

backseat.nvim is designed to be extremely cost-effective. It uses Gemini 2.0 Flash by default, which is one of the most affordable AI models available. Even with the generous assumption that one is in Neovim normal mode 6 hours a day, backseat.nvim will cost only ~$0.01 per day.

## Privacy

- Only your command keystrokes and custom instructions are sent to the API
- No file contents or sensitive data are transmitted
- Commands are processed in batches and cleared after analysis

## License

MIT
