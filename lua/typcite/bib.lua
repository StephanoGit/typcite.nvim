local config = require("typcite.config")

local M = {}

-- ---------------------------------------------------------------- locating

local function is_root(dir, markers)
  for _, marker in ipairs(markers) do
    if vim.uv.fs_stat(dir .. "/" .. marker) then return true end
  end
  return false
end

--- Walk up from `start` looking for a bibliography.
---@param start string|nil directory to start from
---@return string|nil path
function M.locate(start)
  local opts = config.get()
  local dir = start
  if not dir or dir == "" then
    dir = vim.fn.expand("%:p:h")
    if dir == "" then dir = vim.fn.getcwd() end
  end
  dir = vim.fn.fnamemodify(dir, ":p"):gsub("/$", "")

  while true do
    for _, name in ipairs(opts.bib_names) do
      local candidate = dir .. "/" .. name
      if vim.uv.fs_stat(candidate) then return candidate end
    end
    if is_root(dir, opts.root_markers) then break end
    local parent = vim.fn.fnamemodify(dir, ":h")
    if parent == dir then break end
    dir = parent
  end

  if opts.global_bib and vim.uv.fs_stat(vim.fn.expand(opts.global_bib)) then
    return vim.fn.expand(opts.global_bib)
  end
  return nil
end

--- Where a new bibliography would be created if none exists.
function M.default_path(start)
  local dir = start or vim.fn.expand("%:p:h")
  if dir == "" then dir = vim.fn.getcwd() end
  return dir .. "/" .. config.get().bib_names[1]
end

-- ----------------------------------------------------------------- parsing

--- Read a field value starting at `i`. Returns value, next index.
local function read_value(text, i)
  while i <= #text and text:sub(i, i):match("%s") do i = i + 1 end
  if i > #text then return "", i end

  local ch = text:sub(i, i)
  if ch == "{" then
    local depth, start = 0, i
    while i <= #text do
      local c = text:sub(i, i)
      if c == "{" then
        depth = depth + 1
      elseif c == "}" then
        depth = depth - 1
        if depth == 0 then return text:sub(start + 1, i - 1), i + 1 end
      end
      i = i + 1
    end
    return text:sub(start + 1), i
  elseif ch == '"' then
    local start = i + 1
    i = i + 1
    while i <= #text do
      if text:sub(i, i) == '"' and text:sub(i - 1, i - 1) ~= "\\" then
        return text:sub(start, i - 1), i + 1
      end
      i = i + 1
    end
    return text:sub(start), i
  end

  local start = i
  while i <= #text and not text:sub(i, i):match("[,}]") do i = i + 1 end
  return vim.trim(text:sub(start, i - 1)), i
end

--- Parse BibTeX into a list of { type, key, fields }.
---@param text string
---@return table[]
function M.parse(text)
  local entries = {}
  local pos = 1

  while true do
    local at = text:find("@", pos, true)
    if not at then break end

    local etype, after = text:match("^@([%a]+)%s*{()", at)
    if not etype then
      pos = at + 1
    else
      local lower = etype:lower()
      if lower == "comment" or lower == "preamble" or lower == "string" then
        pos = after
      else
        -- find the matching close brace
        local depth, i = 1, after
        while i <= #text and depth > 0 do
          local c = text:sub(i, i)
          if c == "{" then depth = depth + 1 elseif c == "}" then depth = depth - 1 end
          i = i + 1
        end
        local body = text:sub(after, i - 2)

        local key, rest = body:match("^%s*([^,%s]+)%s*,()")
        if key then
          local fields, j = {}, rest
          while j <= #body do
            local name, veq = body:match("^%s*,?%s*([%a_%-]+)%s*=()", j)
            if not name then break end
            local value
            value, j = read_value(body, veq)
            fields[name:lower()] = vim.trim((value:gsub("%s+", " ")))
          end
          table.insert(entries, { type = lower, key = key, fields = fields })
        end
        pos = i
      end
    end
  end

  return entries
end

--- Parse the bibliography at `path`. Missing file yields an empty list.
function M.load(path)
  if not path or not vim.uv.fs_stat(path) then return {} end
  local ok, lines = pcall(vim.fn.readfile, path)
  if not ok then return {} end
  return M.parse(table.concat(lines, "\n"))
end

-- -------------------------------------------------------- key generation

-- Latin-1 and Latin Extended-A characters that appear in author names.
local FOLD = {
  ["á"] = "a", ["à"] = "a", ["â"] = "a", ["ä"] = "a", ["ã"] = "a", ["å"] = "a",
  ["ā"] = "a", ["ă"] = "a", ["ą"] = "a",
  ["é"] = "e", ["è"] = "e", ["ê"] = "e", ["ë"] = "e", ["ē"] = "e", ["ė"] = "e",
  ["ę"] = "e", ["ě"] = "e",
  ["í"] = "i", ["ì"] = "i", ["î"] = "i", ["ï"] = "i", ["ī"] = "i", ["į"] = "i",
  ["ó"] = "o", ["ò"] = "o", ["ô"] = "o", ["ö"] = "o", ["õ"] = "o", ["ø"] = "o",
  ["ō"] = "o", ["ő"] = "o",
  ["ú"] = "u", ["ù"] = "u", ["û"] = "u", ["ü"] = "u", ["ū"] = "u", ["ů"] = "u",
  ["ű"] = "u", ["ų"] = "u",
  ["ñ"] = "n", ["ń"] = "n", ["ň"] = "n",
  ["ç"] = "c", ["ć"] = "c", ["č"] = "c",
  ["ś"] = "s", ["š"] = "s", ["ş"] = "s",
  ["ź"] = "z", ["ż"] = "z", ["ž"] = "z",
  ["ý"] = "y", ["ÿ"] = "y",
  ["ł"] = "l", ["đ"] = "d", ["ğ"] = "g", ["ř"] = "r", ["ť"] = "t", ["ð"] = "d",
  ["þ"] = "t", ["ß"] = "ss", ["æ"] = "ae", ["œ"] = "oe",
}

--- Strip accents and lowercase. Unknown non-ASCII is dropped.
function M.fold(s)
  s = s:lower()
  s = s:gsub("[\194-\244][\128-\191]*", function(c) return FOLD[c] or "" end)
  return s
end

local STOPWORDS = {
  the = true, a = true, an = true, and_ = true, ["and"] = true, ["or"] = true,
  ["of"] = true, ["on"] = true, ["in"] = true, ["for"] = true, with = true,
  from = true, ["to"] = true, at = true, into = true, by = true, using = true,
  via = true, towards = true, toward = true, new = true, novel = true,
  study = true, studies = true, analysis = true, effects = true, effect = true,
  role = true, case = true, review = true,
}

--- Surname of the first author.
function M.first_surname(author)
  if not author or author == "" then return "anon" end
  local first = vim.split(author, "%s+and%s+")[1] or author
  first = vim.trim(first:gsub("[{}]", ""))

  local surname
  if first:find(",", 1, true) then
    surname = first:sub(1, first:find(",", 1, true) - 1)
  else
    local parts = vim.split(vim.trim(first), "%s+")
    surname = parts[#parts] or "anon"
  end

  surname = M.fold(surname):gsub("[^a-z]", "")
  return surname ~= "" and surname or "anon"
end

function M.year(fields)
  for _, candidate in ipairs({ fields.year or "", fields.date or "" }) do
    local y = candidate:match("[12]%d%d%d")
    if y then return y end
  end
  return "nd"
end

function M.title_word(title)
  if not title or title == "" then return "untitled" end
  local cleaned = M.fold(title):gsub("[^a-z%s]", " ")
  for word in cleaned:gmatch("%S+") do
    if #word > 3 and not STOPWORDS[word] then return word end
  end
  return "untitled"
end

--- author2024firstword, with b/c/d suffixes on collision.
---@param fields table
---@param taken table<string, boolean>
function M.make_key(fields, taken)
  local opts = config.get()
  local base
  if type(opts.key_format) == "function" then
    base = opts.key_format(fields)
  else
    base = M.first_surname(fields.author or fields.editor or "")
      .. M.year(fields)
      .. M.title_word(fields.title or "")
  end

  if not taken[base] then return base end
  for c in ("bcdefghijklmnopqrstuvwxyz"):gmatch(".") do
    if not taken[base .. c] then return base .. c end
  end
  local n = 2
  while taken[base .. n] do n = n + 1 end
  return base .. n
end

-- ----------------------------------------------------------------- writing

function M.render(etype, key, fields)
  local names = vim.tbl_keys(fields)
  table.sort(names)

  local width = 1
  for _, n in ipairs(names) do width = math.max(width, #n) end

  local lines = { ("@%s{%s,"):format(etype, key) }
  for _, n in ipairs(names) do
    table.insert(lines, ("  %s = {%s},"):format(n .. (" "):rep(width - #n), fields[n]))
  end
  table.insert(lines, "}")
  return table.concat(lines, "\n")
end

local function strip_dropped(fields)
  local drop = {}
  for _, f in ipairs(config.get().drop_fields) do drop[f] = true end

  local out = {}
  for k, v in pairs(fields) do
    if not drop[k] and v and v ~= "" then out[k] = v end
  end
  return out
end

--- Add one parsed BibTeX record to `path`.
--- Returns key, was_new. Existing DOIs are not duplicated.
---@param path string
---@param bibtex string
---@return string|nil key
---@return boolean is_new
function M.add(path, bibtex)
  local parsed = M.parse(bibtex)
  if #parsed == 0 then return nil, false end

  local incoming = parsed[1]
  local fields = strip_dropped(incoming.fields)

  local existing = M.load(path)
  local taken = {}
  for _, e in ipairs(existing) do taken[e.key] = true end

  local doi = (fields.doi or ""):lower()
  if doi ~= "" then
    for _, e in ipairs(existing) do
      if (e.fields.doi or ""):lower() == doi then return e.key, false end
    end
  end

  local key = M.make_key(fields, taken)
  local rendered = M.render(incoming.type, key, fields)

  local out = {}
  if vim.uv.fs_stat(path) then
    out = vim.fn.readfile(path)
    while #out > 0 and vim.trim(out[#out]) == "" do table.remove(out) end
    if #out > 0 then table.insert(out, "") end
  end
  for _, line in ipairs(vim.split(rendered, "\n")) do table.insert(out, line) end

  vim.fn.mkdir(vim.fn.fnamemodify(path, ":h"), "p")
  vim.fn.writefile(out, path)
  return key, true
end

return M
