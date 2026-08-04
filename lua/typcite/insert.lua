local config = require("typcite.config")

local M = {}

--- Capture where the cursor was when the user triggered the action, so an
--- async fetch that finishes later still inserts in the right place.
---@return table anchor
function M.anchor()
  return {
    win = vim.api.nvim_get_current_win(),
    buf = vim.api.nvim_get_current_buf(),
    pos = vim.api.nvim_win_get_cursor(0),
    ft = vim.bo.filetype,
  }
end

--- How a citation is written in this filetype.
---@param ft string|nil
---@return string
function M.format_for(ft)
  local formats = config.get().cite_format
  return formats[ft or ""] or formats.default or "@%s"
end

--- Write the citation into the buffer the user was in.
---@param key string
---@param anchor table|nil
---@return boolean ok
function M.put(key, anchor)
  if not key or key == "" then return false end
  anchor = anchor or M.anchor()

  if not vim.api.nvim_buf_is_valid(anchor.buf) then
    vim.notify("typcite: buffer is gone, citation key is " .. key,
      vim.log.levels.WARN)
    return false
  end

  local text = M.format_for(anchor.ft):format(key)
  local row, col = anchor.pos[1] - 1, anchor.pos[2]

  local line = vim.api.nvim_buf_get_lines(anchor.buf, row, row + 1, false)[1] or ""
  col = math.min(col, #line)
  -- put after the character under the cursor, matching `p` rather than `P`
  if #line > 0 then col = col + 1 end

  vim.api.nvim_buf_set_text(anchor.buf, row, col, row, col, { text })

  if vim.api.nvim_win_is_valid(anchor.win) then
    pcall(vim.api.nvim_win_set_cursor, anchor.win, { row + 1, col + #text })
  end
  return true
end

return M
