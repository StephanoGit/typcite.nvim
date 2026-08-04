local config = require("typcite.config")
local bib = require("typcite.bib")

local M = {}

function M.check()
  local start = vim.health.start or vim.health.report_start
  local ok = vim.health.ok or vim.health.report_ok
  local warn = vim.health.warn or vim.health.report_warn
  local err = vim.health.error or vim.health.report_error

  start("typcite")

  if vim.fn.has("nvim-0.10") == 1 then
    ok("Neovim 0.10 or newer")
  else
    err("Neovim 0.10+ required (vim.system, vim.json, vim.uv)")
  end

  if vim.fn.executable("curl") == 1 then
    ok("curl: " .. vim.fn.exepath("curl"))
  else
    err("curl not found. Nothing can be fetched without it.")
  end

  local opts = config.get()
  local cmd = opts.pdf2doi_cmd or "pdf2doi"
  if not opts.use_pdf2doi then
    ok("pdf2doi disabled in config, using the built-in PDF scanner")
  elseif vim.fn.executable(cmd) == 1 then
    ok("pdf2doi: " .. vim.fn.exepath(cmd))
  else
    warn(("%q not on Neovim's PATH, falling back to the built-in scanner.\n"
      .. "  Install with `pipx install pdf2doi`, or if it is installed "
      .. "already but nvim cannot see it, set pdf2doi_cmd to its absolute "
      .. "path (`which pdf2doi` in your shell)."):format(cmd))
  end

  start("typcite: bibliography")

  local path = bib.locate()
  if path then
    ok(("%s (%d entries)"):format(path, #bib.load(path)))
  else
    warn("none found from the current directory. One would be created at "
      .. bib.default_path())
  end

  start("typcite: citation formats")

  -- Note: this deliberately does not read the current buffer's filetype,
  -- because :checkhealth runs inside its own scratch buffer.
  local names = {}
  for ft in pairs(opts.cite_format) do
    if ft ~= "default" then table.insert(names, ft) end
  end
  table.sort(names)

  for _, ft in ipairs(names) do
    ok(("%-10s %s"):format(ft, opts.cite_format[ft]:format("key")))
  end
  ok(("%-10s %s"):format("(other)", opts.cite_format.default:format("key")))
end

return M
