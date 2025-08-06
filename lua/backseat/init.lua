local M = {}

local api = require("backseat.api")
local monitor = require("backseat.monitor")
local persistence = require("backseat.persistence")
local config = require("backseat.config")
local commands = require("backseat.commands")

function M.setup(opts)
	local cfg = config.setup(opts)

	if cfg.ollama_host then
		api.fetch_ollama_models(cfg)
	end

	local instructions = persistence.load_instructions()
	local replacement_rules = persistence.load_replacement_rules()
	
	monitor.set_replacement_rules(replacement_rules)
	monitor.create_command_monitor(cfg)

	commands.setup_commands()

	if cfg.anthropic_api_key or cfg.gemini_api_key or cfg.ollama_host then
		commands.start_periodic_analysis()
	end
end

function M.get_recent_commands(limit)
	return monitor.get_recent_commands(limit)
end

M.command_history = monitor.command_history
M.instructions = persistence.instructions
M.replacement_rules = persistence.replacement_rules
M.config = config.current

return M