local config = require("typcite.config")
local bib = require("typcite.bib")
local detect = require("typcite.detect")
local sources = require("typcite.sources")
local insert = require("typcite.insert")

local M = {}

local function notify(msg, level)
  vim.notify("typcite: " .. msg, level or vim.log.levels.INFO)
end

local function resolve_bib()
  return bib.locate() or bib.default_path()
end

--- Write a fetched record and put the key in the buffer.
local function commit(bibtex, anchor, path)
  vim.schedule(function()
    local key, is_new = bib.add(path, bibtex)
    if not key then
      return notify("could not parse the entry that came back", vim.log.levels.ERROR)
    end
    insert.put(key, anchor)
    if not is_new then
      notify(key .. " was already in " .. vim.fn.fnamemodify(path, ":t"))
    end
  end)
end

local function fail(err)
  vim.schedule(function() notify(err, vim.log.levels.ERROR) end)
end

-- ------------------------------------------------------------------ pickers

local function pick(items, prompt, format_item, on_choice)
  vim.schedule(function()
    vim.ui.select(items, { prompt = prompt, format_item = format_item }, on_choice)
  end)
end

local function fit(s, width)
  s = tostring(s or ""):gsub("%s+", " ")
  if vim.fn.strdisplaywidth(s) <= width then return s end
  return vim.fn.strcharpart(s, 0, width - 1) .. "…"
end

local function room_for(head)
  return math.max(24, math.floor(vim.o.columns * 0.9) - #head - 8)
end

-- ------------------------------------------------------------------ actions

--- The single entry point. Works out what `input` is and does the right thing.
---@param input string|nil  nil prompts for it
function M.capture(input)
  local anchor = insert.anchor()
  local path = resolve_bib()

  local function run(value)
    if not value or vim.trim(value) == "" then return end

    local kind, payload = detect.classify(value)

    if kind == "doi" then
      sources.doi(payload, function(bt, err)
        if not bt then return fail(err) end
        commit(bt, anchor, path)
      end)
    elseif kind == "arxiv" then
      sources.arxiv(payload, function(bt, err)
        if not bt then return fail(err) end
        commit(bt, anchor, path)
      end)
    elseif kind == "isbn" then
      sources.isbn(payload, function(bt, err)
        if not bt then return fail(err) end
        commit(bt, anchor, path)
      end)
    elseif kind == "pdf" then
      M.from_pdf(payload, anchor, path)
    else
      M.search(payload, anchor, path)
    end
  end

  if input then return run(input) end

  vim.ui.input({ prompt = "Cite (DOI, arXiv, ISBN, PDF path or title): " }, run)
end

--- Crossref search, then pick.
function M.search(query, anchor, path)
  anchor = anchor or insert.anchor()
  path = path or resolve_bib()

  sources.search(query, function(results, err)
    if not results then return fail(err) end
    if #results == 0 then return fail("no matches for that query") end

    pick(results, "Add citation:", function(r)
      local head = ("%s %s  "):format(r.who, r.year)
      local tail = r.venue ~= "" and (r.title .. "  [" .. r.venue .. "]") or r.title
      return head .. fit(tail, room_for(head))
    end, function(choice)
      if not choice then return end
      sources.doi(choice.doi, function(bt, e)
        if not bt then return fail(e) end
        commit(bt, anchor, path)
      end)
    end)
  end)
end

--- Pull an identifier out of a PDF, then add it.
function M.from_pdf(file, anchor, path)
  anchor = anchor or insert.anchor()
  path = path or resolve_bib()

  sources.pdf(file, function(ids, err)
    if not ids then return fail(err) end

    local function use(doi)
      sources.doi(doi, function(bt, e)
        if not bt then return fail(e) end
        commit(bt, anchor, path)
      end)
    end

    if #ids == 1 then return use(ids[1]) end
    pick(ids, "Which identifier?", function(d) return d end, function(choice)
      if choice then use(choice) end
    end)
  end)
end

--- Pick from what is already in the bibliography. No network.
function M.pick_existing()
  local anchor = insert.anchor()
  local path = bib.locate()
  if not path then
    return notify("no bibliography found for this project", vim.log.levels.WARN)
  end

  local entries = bib.load(path)
  if #entries == 0 then
    return notify(vim.fn.fnamemodify(path, ":t") .. " is empty", vim.log.levels.WARN)
  end

  local width = 0
  for _, e in ipairs(entries) do width = math.max(width, #e.key) end
  width = math.min(width, 28)

  table.sort(entries, function(a, b) return a.key < b.key end)

  vim.ui.select(entries, {
    prompt = "Cite:",
    format_item = function(e)
      local head = ("%-" .. width .. "s  %s  "):format(
        fit(e.key, width), bib.year(e.fields))
      return head .. fit(e.fields.title or "(untitled)", room_for(head))
    end,
  }, function(choice)
    if choice then insert.put(choice.key, anchor) end
  end)
end

--- Add whatever is on the system clipboard.
function M.from_clipboard()
  local text = vim.trim(vim.fn.getreg("+") or "")
  if text == "" then return M.capture() end
  M.capture(text)
end

--- Open the active bibliography, or close it if it is already showing.
function M.toggle_bib()
  local path = bib.locate()
  if not path then
    return notify("no bibliography found for this project", vim.log.levels.WARN)
  end

  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(win)) == path then
      return vim.api.nvim_win_close(win, false)
    end
  end
  vim.cmd("vsplit " .. vim.fn.fnameescape(path))
end

-- -------------------------------------------------------------------- setup

local function set_keymaps()
  local p = config.get().keymap_prefix
  local maps = {
    { p .. "c", M.pick_existing, "Cite: pick from bibliography" },
    { p .. "a", M.capture,       "Cite: add (DOI, arXiv, ISBN, PDF, title)" },
    { p .. "d", M.from_clipboard, "Cite: add from clipboard" },
    { p .. "b", M.toggle_bib,    "Cite: toggle bibliography" },
  }
  for _, m in ipairs(maps) do
    vim.keymap.set("n", m[1], m[2], { desc = m[3] })
  end
end

---@param opts table|nil
function M.setup(opts)
  config.setup(opts)
  if config.get().default_keymaps then set_keymaps() end
end

return M
