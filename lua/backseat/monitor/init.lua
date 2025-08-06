local M = {}

M.command_history = {}
M.replacement_rules = {}
M.last_notification_time = {}

local function normalize_key(raw)
	local rt = vim.api.nvim_replace_termcodes(raw, true, true, true)
	local tok = vim.fn.keytrans(rt)

	local leader = vim.g.mapleader or "\\"
	local localleader = vim.g.maplocalleader or "\\"
	if tok == leader then
		tok = "<Leader>"
	end
	if tok == localleader then
		tok = "<LocalLeader>"
	end

	tok = tok:gsub("^<([^>]+)>$", function(inner)
		inner = inner:gsub("<", "<lt>")
		return "<" .. inner .. ">"
	end)

	tok = tok:gsub("[%z\1-\31]", "")

	return tok
end

local function check_command_against_rules(command_str)
	for original, replacement in pairs(M.replacement_rules) do
		if command_str:sub(-#original) == original then
			return true, replacement, original
		end
	end
	return false, nil, nil
end

function M.create_command_monitor(config)
	vim.on_key(function(key)
		if not config.enable_monitoring or vim.fn.mode() ~= "n" then
			return
		end

		local translated = normalize_key(key)

		if translated:match("^<[^>]+>$") or translated:match("^[^<]$") then
			table.insert(M.command_history, translated)
		end

		if #M.command_history > config.max_history_size then
			table.remove(M.command_history, 1)
		end

		local current_command = table.concat(M.command_history, "")

		local should_replace, replacement, original = check_command_against_rules(current_command)
		if should_replace then
			local current_time = vim.loop.now()
			local last_time = M.last_notification_time[original] or 0
			local time_diff = current_time - last_time

			for _ = 1, #original do
				table.remove(M.command_history)
			end

			if time_diff >= 3000 then
				M.last_notification_time[original] = current_time
				vim.schedule(function()
					for _ = 1, #original do
						table.remove(M.command_history)
					end

					vim.notify(
						string.format("Backseat: Use '%s' instead of '%s'", replacement, original),
						vim.log.levels.WARN
					)
				end)
			end
		end
	end)
end

function M.get_recent_commands(limit)
	limit = limit or 10
	local recent = {}
	local start_idx = math.max(1, #M.command_history - limit + 1)
	for i = start_idx, #M.command_history do
		table.insert(recent, M.command_history[i])
	end
	return recent
end

function M.clear_history()
	M.command_history = {}
	M.last_notification_time = {}
end

function M.set_replacement_rules(rules)
	M.replacement_rules = rules
end

return M
