local M = {}

local DEFAULT_MODELS = {
	"claude-3-5-haiku-latest",
	"gemini-2.5-flash",
	"gemini-2.5-flash-lite",
	"gemini-2.0-flash",
}

local MODELS = vim.deepcopy(DEFAULT_MODELS)

function M.get_models()
	return MODELS
end

function M.fetch_ollama_models(config)
	local ok, curl = pcall(require, "plenary.curl")
	if not ok then
		return
	end

	local url = (config.ollama_host or "http://localhost:11434") .. "/api/tags"

	curl.get(url, {
		timeout = 5000,
		callback = function(response)
			if response.status == 200 then
				local success, data = pcall(vim.json.decode, response.body)
				if success and data and data.models then
					vim.schedule(function()
						MODELS = vim.deepcopy(DEFAULT_MODELS)
						for _, model in ipairs(data.models) do
							if model.name then
								local model_name = model.name:gsub(":latest$", "")
								table.insert(MODELS, model_name)
							end
						end
					end)
				end
			end
		end,
	})
end

function M.make_google_request(prompt, config)
	if not config.gemini_api_key then
		vim.notify("Backseat: Gemini API key not configured", vim.log.levels.ERROR)
		return
	end

	local ok, curl = pcall(require, "plenary.curl")
	if not ok then
		vim.notify("Backseat: plenary.nvim is required for API requests", vim.log.levels.ERROR)
		return
	end

	local url =
		string.format("https://generativelanguage.googleapis.com/v1beta/models/%s:generateContent", config.model)

	local headers = {
		["content-type"] = "application/json",
		["x-goog-api-key"] = config.gemini_api_key,
	}

	local body = vim.json.encode({
		contents = {
			{
				parts = {
					{
						text = prompt,
					},
				},
			},
		},
		generationConfig = {
			maxOutputTokens = config.max_tokens,
			temperature = 0.1,
		},
	})

	curl.post(url, {
		headers = headers,
		body = body,
		callback = function(response)
			if response.status == 200 then
				local data = vim.json.decode(response.body)
				if
					data
					and data.candidates
					and data.candidates[1]
					and data.candidates[1].content
					and data.candidates[1].content.parts
					and data.candidates[1].content.parts[1]
				then
					local text = data.candidates[1].content.parts[1].text
					if not string.find(text or "", "No feedback") then
						vim.schedule(function()
							vim.notify(config.model .. " Analysis:\n" .. text, vim.log.levels.INFO)
						end)
					end
				else
					vim.schedule(function()
						vim.notify("Backseat: API request failed - " .. response.status, vim.log.levels.ERROR)
					end)
				end
			end
		end,
	})
end

function M.make_ollama_request(prompt, config)
	local ok, curl = pcall(require, "plenary.curl")
	if not ok then
		vim.notify("Backseat: plenary.nvim is required for API requests", vim.log.levels.ERROR)
		return
	end

	local url = config.ollama_host .. "/api/generate"

	local headers = {
		["content-type"] = "application/json",
	}

	local body = vim.json.encode({
		model = config.model,
		prompt = prompt,
		stream = false,
		options = {
			num_predict = config.max_tokens,
			temperature = 0.1,
		},
	})

	curl.post(url, {
		headers = headers,
		body = body,
		timeout = 30000,
		callback = function(response)
			if response.status == 200 then
				local data = vim.json.decode(response.body)
				if data and data.response then
					local text = data.response
					if not string.find(text or "", "No feedback") then
						vim.schedule(function()
							vim.notify(config.model .. " Analysis:\n" .. text, vim.log.levels.INFO)
						end)
					end
				end
			else
				vim.schedule(function()
					local error_msg = "Backseat: Ollama request failed - " .. response.status
					if response.body then
						local ok, err_data = pcall(vim.json.decode, response.body)
						if ok and err_data.error then
							error_msg = error_msg .. " (" .. err_data.error .. ")"
						end
					end
					vim.notify(error_msg, vim.log.levels.ERROR)
				end)
			end
		end,
	})
end

function M.make_anthropic_request(prompt, config)
	if not config.anthropic_api_key then
		vim.notify("Backseat: API key not configured", vim.log.levels.ERROR)
		return
	end

	local ok, curl = pcall(require, "plenary.curl")
	if not ok then
		vim.notify("Backseat: plenary.nvim is required for API requests", vim.log.levels.ERROR)
		return
	end

	local headers = {
		["x-api-key"] = config.anthropic_api_key,
		["anthropic-version"] = "2023-06-01",
		["content-type"] = "application/json",
	}

	local body = vim.json.encode({
		model = config.model,
		max_tokens = config.max_tokens,
		messages = {
			{
				role = "user",
				content = {
					{
						type = "text",
						text = prompt,
					},
				},
			},
		},
	})

	local url = "https://api.anthropic.com/v1/messages"

	curl.post(url, {
		headers = headers,
		body = body,
		callback = function(response)
			if response.status == 200 then
				local data = vim.json.decode(response.body)
				if
					data
					and data.content
					and data.content[1]
					and not string.find(data.content[1].text or "", "No feedback")
				then
					vim.schedule(function()
						vim.notify(config.model .. " Analysis:\n" .. data.content[1].text, vim.log.levels.INFO)
					end)
				end
			else
				vim.schedule(function()
					vim.notify("Backseat: API request failed - " .. response.status, vim.log.levels.ERROR)
				end)
			end
		end,
	})
end

function M.make_request(prompt, config)
	if config.model:match("^gemini") then
		M.make_google_request(prompt, config)
	elseif config.model:match("^claude") then
		M.make_anthropic_request(prompt, config)
	else
		M.make_ollama_request(prompt, config)
	end
end

return M