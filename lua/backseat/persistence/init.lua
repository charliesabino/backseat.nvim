local M = {}

local data_dir = vim.fn.stdpath("data") .. "/backseat"
local instructions_file = data_dir .. "/instructions.txt"
local replacement_rules_file = data_dir .. "/replacement_rules.txt"

M.instructions = ""
M.replacement_rules = {}

function M.load_instructions()
	vim.fn.mkdir(data_dir, "p")
	local f = io.open(instructions_file, "r")
	if f then
		M.instructions = f:read("*all")
		f:close()
	end
	return M.instructions
end

function M.save_instructions(instructions)
	vim.fn.mkdir(data_dir, "p")
	local f = io.open(instructions_file, "w")
	if f then
		f:write(instructions)
		f:close()
	end
	M.instructions = instructions
end

function M.load_replacement_rules()
	vim.fn.mkdir(data_dir, "p")
	local f = io.open(replacement_rules_file, "r")
	if f then
		local content = f:read("*all")
		f:close()
		M.replacement_rules = {}
		for line in content:gmatch("[^\r\n]+") do
			local original, replacement = line:match("^([^,]+),(.+)$")
			if original and replacement then
				M.replacement_rules[original] = replacement
			end
		end
	end
	return M.replacement_rules
end

function M.save_replacement_rules(rules)
	vim.fn.mkdir(data_dir, "p")
	local f = io.open(replacement_rules_file, "w")
	if f then
		for original, replacement in pairs(rules) do
			f:write(original .. "," .. replacement .. "\n")
		end
		f:close()
	end
	M.replacement_rules = rules
end

function M.get_instructions()
	return M.instructions
end

function M.get_replacement_rules()
	return M.replacement_rules
end

return M