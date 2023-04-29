local job = require("plenary.job")
local Config = require("chatgpt.config")

local Api = {}

function Api.completions(custom_params, cb)
  local params = vim.tbl_extend("keep", custom_params, Config.options.openai_params)
  Api.make_call(params, cb)
end

function Api.chat_completions(custom_params, cb)
  local params = vim.tbl_extend("keep", custom_params, Config.options.openai_params)
  Api.make_call(params, cb)
end

function Api.edits(custom_params, cb)
  local params = vim.tbl_extend("keep", custom_params, Config.options.openai_edit_params)
  Api.make_call(params, cb)
end

function Api.make_call(params, cb)
-- set custom url
  local url = "http://localhost:5000/send_message"
  local message = ""
  local messages = {}
  local id = ""
-- reformat params for custom call
  message = params.prompt
  if not message then
    messages = params.messages
    if type(messages) == "string" then
        message = messages
    elseif type(messages) == "table" then
        message = messages[#messages].content
    else
        local input = params.input
        local instruction = params.instruction
        message = instruction .. "On the following code: " .. input
    end
  end
  message = string.gsub(message, '\"','\\"')
  message = string.gsub(message, "'","\'")
  message = string.gsub(message, "\n","\\n")

  id = params.id
  if id == nil then
    id = "0"
  end
  local jsonPayload = string.format('{"message": "%s", "id": "%s"}', message, id)

  Api.job = job
    :new({
      command = "curl",
      args = {
        url,
        "-X POST",
        "-H",
        "Content-Type: application/json",
        "-d", jsonPayload
      },
      on_exit = vim.schedule_wrap(function(response, exit_code)
        Api.handle_response(response, exit_code, cb)
      end),
    })
    :start()
end

Api.handle_response = vim.schedule_wrap(function(response, exit_code, cb)
  if exit_code ~= 0 then
    vim.notify("An Error Occurred ...", vim.log.levels.ERROR)
    cb("ERROR: API Error")
  end

  local result = table.concat(response:result(), "\n")
  local json = vim.fn.json_decode(result)
  if json == nil then
    cb("No Response.")
  elseif json.error then
    cb("// API ERROR: " .. json.error.message)
  else
    local message = json.choices[1].message
    if message ~= nil then
      local response_text = json.choices[1].message.content
      if type(response_text) == "string" and response_text ~= "" then
        cb(response_text, json.usage)
      else
        cb("...")
      end
    else
      local response_text = json.choices[1].text
      if type(response_text) == "string" and response_text ~= "" then
        cb(response_text, json.usage)
      else
        cb("...")
      end
    end
  end
end)

function Api.reset_conversation()
-- set custom url
  local url = "http://localhost:5000/reset_conversation"
  Api.job = job
    :new({
      command = "curl",
      args = {
        url,
        "-X GET",
      },
    })
    :start()
end

function Api.close()
  if Api.job then
    job:shutdown()
  end
end

return Api
