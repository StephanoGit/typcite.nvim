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
local function commit(bibtex, anchor, path, extra)
  vim.schedule(function()
    local key, is_new = bib.add(path, bibtex, extra)
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
        local extra = nil
        if config.get().record_file_field then
          extra = { file = bib.relativise(file, path) }
        end
        commit(bt, anchor, path, extra)
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

--- The citation key under the cursor, in any supported syntax.
---@return string|nil
function M.key_under_cursor()
  local word = vim.fn.expand("<cWORD>")
  if word == "" then return nil end

  -- \cite{key}, \parencite{key}, [@key], @key, [cite:@key]
  local key = word:match("\\%a*cite%*?%b{}")
  if key then return key:match("{(.-)}"):match("^([^,]+)") end

  key = word:match("@([%w%-_:%.]+)")
  if key then return (key:gsub("[%.,;:%)%]}]+$", "")) end
  return nil
end

--- Open the PDF for a citation. Uses the key under the cursor, or prompts.
---@param key string|nil
function M.open_pdf(key)
  local path = bib.locate()
  if not path then
    return notify("no bibliography found for this project", vim.log.levels.WARN)
  end

  key = key or M.key_under_cursor()
  local entries = bib.load(path)

  local function launch(target)
    local cmd = config.get().open_cmd
    if type(cmd) == "function" then return cmd(target) end
    if not cmd then
      cmd = vim.fn.has("mac") == 1 and "open" or "xdg-open"
    end
    vim.system({ cmd, target }, { detach = true })
  end

  --- Nothing on disk. Try a legal open-access copy, then the publisher page.
  local function go_online(entry)
    local opts = config.get()
    local doi = entry.fields.doi

    if not opts.online_fallback then
      return notify(("no PDF on disk for %s. Looked in: %s"):format(
        entry.key, table.concat(opts.pdf_dirs, ", ")), vim.log.levels.WARN)
    end
    if not doi or doi == "" then
      return notify(entry.key .. " has no PDF on disk and no DOI to look up",
        vim.log.levels.WARN)
    end

    notify("no local copy, looking for an open-access one...")

    sources.open_access(doi, function(info, err)
      vim.schedule(function()
        if not info then
          notify("open-access lookup failed (" .. tostring(err)
            .. "), opening the publisher page", vim.log.levels.WARN)
          return launch("https://doi.org/" .. doi)
        end

        if not info.pdf_url then
          if not info.is_oa then
            notify(entry.key .. " has no open-access copy, opening the "
              .. "publisher page. Your institution may have access.")
          end
          return launch(info.landing_url or ("https://doi.org/" .. doi))
        end

        if not config.get().download_oa then
          return launch(info.pdf_url)
        end

        local dest = vim.fn.fnamemodify(path, ":h") .. "/"
          .. config.get().download_dir .. "/" .. entry.key .. ".pdf"

        notify("downloading open-access copy...")
        sources.download(info.pdf_url, dest, function(ok, derr)
          if not ok then
            notify(tostring(derr) .. ", opening in the browser instead",
              vim.log.levels.WARN)
            return launch(info.pdf_url)
          end
          bib.set_field(path, entry.key, "file",
            bib.relativise(dest, path))
          notify("saved to " .. config.get().download_dir .. "/"
            .. entry.key .. ".pdf")
          launch(dest)
        end)
      end)
    end)
  end

  local function open(entry)
    local file = bib.pdf_for(entry, path)
    if not file then return go_online(entry) end
    launch(file)
  end

  if key then
    for _, e in ipairs(entries) do
      if e.key == key then return open(e) end
    end
    notify(key .. " is not in the bibliography", vim.log.levels.WARN)
  end

  -- no key under the cursor: let them choose, marking what is already local
  if #entries == 0 then
    return notify("the bibliography is empty", vim.log.levels.WARN)
  end

  table.sort(entries, function(a, b) return a.key < b.key end)
  local width = 0
  for _, e in ipairs(entries) do width = math.max(width, #e.key) end
  width = math.min(width, 28)

  vim.ui.select(entries, {
    prompt = "Open PDF:",
    format_item = function(e)
      local mark = bib.pdf_for(e, path) and "*" or " "
      local head = ("%s %-" .. width .. "s  %s  "):format(
        mark, fit(e.key, width), bib.year(e.fields))
      return head .. fit(e.fields.title or "(untitled)", room_for(head))
    end,
  }, function(choice) if choice then open(choice) end end)
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
    { p .. "o", M.open_pdf,      "Cite: open the PDF for this citation" },
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
