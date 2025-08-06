# backseat.nvim

A Neovim plugin that provides instant feedback for command improvements with customizable replacement rules and optional AI-powered habit analysis.

<https://github.com/user-attachments/assets/62874323-30e8-4540-82bf-5ac0c4197af0>

## Table of Contents

- [Features](#features)
- [Requirements](#requirements)
- [Installation](#installation)
- [Configuration](#configuration)
  - [API Key](#api-key)
  - [Options](#options)
- [Usage](#usage)
  - [Quick Start: Replacement Rules](#quick-start-replacement-rules)
  - [AI-Powered Analysis (Optional)](#ai-powered-analysis-optional)
  - [Commands](#commands)
- [How It Works](#how-it-works)
- [Example Instructions](#example-instructions)
- [Cost](#cost)
- [Privacy](#privacy)
- [License](#license)

## Features

- **Instant replacement rules**: Define simple command substitutions that provide immediate feedback as you type
- **Real-time command monitoring**: Tracks your normal mode commands and suggests improvements instantly
- **Persistent settings**: Your custom replacement rules are saved and loaded automatically
- **AI-powered analysis** *(optional)*: Use AI models to analyze complex patterns and provide deeper insights
- **Customizable instructions** *(optional)*: Define natural language rules for AI-based habit analysis
- **Periodic feedback** *(optional)*: Automatically analyze command history at configurable intervals

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

### Quick Start: Replacement Rules

The primary feature of backseat.nvim is instant feedback through replacement rules. Simply define command substitutions that will alert you immediately when you use inefficient commands:

```vim
:BackseatReplacementRules
```

This opens a buffer where you can define simple key-value pairs:

- `w,<Right>` - suggests using `w` instead of arrow keys
- `0,<Home>` - suggests using `0` instead of Home key
- `gg,<C-Home>` - suggests using `gg` instead of Ctrl+Home
- `ge,be` - suggests using `ge` instead of `be` for consistency

**Instant feedback**: As soon as you type a command that has a replacement rule, you'll get an immediate notification suggesting the better alternative. This is perfect for breaking specific bad habits quickly.

### AI-Powered Analysis (Optional)

For users who want deeper insights into their Vim habits, backseat.nvim offers optional AI-powered analysis that can understand complex patterns and context:

```vim
:BackseatModelInstructions
```

Write natural language instructions for the AI to analyze:

- "Use `w` and `b` instead of holding `h` and `l`"
- "Prefer `f` and `t` motions over repeated `w`"
- "Use `ci{` instead of `di{i`"
- "Avoid excessive visual mode for simple operations"

The AI will periodically analyze your command history and provide feedback on complex patterns that simple replacement rules can't catch.

Both replacement rules and model instructions are automatically saved and persist between sessions.

### Commands

#### Core Commands

| Command | Description |
|---------|-------------|
| `:BackseatReplacementRules` | Open/edit simple replacement rules (instant feedback) |
| `:ShowCommandHistory` | Display recent command history |

#### AI Analysis Commands (Optional)

| Command | Description |
|---------|-------------|
| `:BackseatModelInstructions` | Open/edit AI-analyzed instructions (periodic feedback) |
| `:BackseatAnalyze` | Manually trigger AI analysis of recent commands |
| `:BackseatStartAnalysis` | Start periodic automatic analysis |
| `:BackseatStopAnalysis` | Stop periodic automatic analysis |
| `:BackseatSelectModel` | Select which AI model to use |
| `:BackseatRefreshModels` | Refresh available Ollama models |

## How It Works

### Replacement Rules (Primary Feature)

1. The plugin monitors your normal mode keystrokes
2. Each keystroke is instantly checked against your replacement rules
3. If a match is found, you get an immediate notification with the suggested improvement
4. No API calls needed - works completely offline for instant feedback

### AI Analysis (Optional Enhancement)

1. Command history is built from your keystrokes
2. Every `analysis_interval` seconds, recent commands are sent to the AI model
3. The AI analyzes commands against your model instructions for complex pattern matching
4. If patterns are detected that violate your instructions, you receive contextual feedback

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

**Replacement rules are completely free** - they work offline with no API calls.

For optional AI analysis: backseat.nvim is designed to be extremely cost-effective. It uses Gemini 2.0 Flash by default, which is one of the most affordable AI models available. Even with the generous assumption that one is in Neovim normal mode 6 hours a day, AI analysis will cost only ~$0.01 per day.

## Privacy

- **Replacement rules work completely offline** - no data is sent anywhere
- For AI analysis (if enabled):
  - Only command keystrokes and custom instructions are sent to the API
  - No file contents or sensitive data are transmitted
  - Commands are processed in batches and cleared after analysis

## License

MIT
