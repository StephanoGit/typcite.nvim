if vim.g.loaded_typcite then return end
vim.g.loaded_typcite = true

vim.api.nvim_create_user_command("Typcite", function(opts)
  local typcite = require("typcite")
  local sub = opts.fargs[1]

  if sub == nil then
    typcite.capture()
  elseif sub == "add" then
    local rest = table.concat(vim.list_slice(opts.fargs, 2), " ")
    typcite.capture(rest ~= "" and rest or nil)
  elseif sub == "pick" then
    typcite.pick_existing()
  elseif sub == "bib" then
    typcite.toggle_bib()
  elseif sub == "clipboard" then
    typcite.from_clipboard()
  else
    typcite.capture(opts.args)
  end
end, {
  nargs = "*",
  complete = function(lead)
    return vim.tbl_filter(function(c) return c:find(lead, 1, true) == 1 end,
      { "add", "pick", "bib", "clipboard" })
  end,
  desc = "Capture a citation",
})
