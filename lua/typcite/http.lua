local config = require("typcite.config")

local M = {}

-- Resolved once at require time. http.get can be reached from inside a
-- vim.system callback, which runs in a fast event context where vim.fn
-- calls raise E5560.
local HAS_CURL = vim.fn.executable("curl") == 1

--- GET a url asynchronously via curl.
---@param url string
---@param opts table|nil { accept = string }
---@param cb fun(body: string|nil, err: string|nil)
function M.get(url, opts, cb)
  opts = opts or {}

  if not HAS_CURL then
    return cb(nil, "curl is not installed")
  end

  local cmd = {
    "curl", "-sSL",
    "--max-time", tostring(config.get().timeout),
    "-w", "\n%{http_code}",
  }
  if opts.accept then
    vim.list_extend(cmd, { "-H", "Accept: " .. opts.accept })
  end
  vim.list_extend(cmd, { "-H", "User-Agent: typcite.nvim", url })

  vim.system(cmd, { text = true }, function(res)
    if res.code ~= 0 then
      return cb(nil, vim.trim(res.stderr ~= "" and res.stderr or "curl failed"))
    end

    local body = res.stdout or ""
    local status = body:match("(%d%d%d)%s*$") or "000"
    body = body:gsub("%s*%d%d%d%s*$", "")

    if status:sub(1, 1) ~= "2" then
      return cb(nil, "HTTP " .. status)
    end
    cb(body, nil)
  end)
end

return M
