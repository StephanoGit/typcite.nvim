local config = require("typcite.config")
local http = require("typcite.http")

local M = {}

local function encode(s)
  return (s:gsub("[^%w%-%._~/:]", function(c)
    return string.format("%%%02X", string.byte(c))
  end))
end

-- ------------------------------------------------------------- doi / arxiv

--- Content negotiation against doi.org returns BibTeX directly.
---@param doi string
---@param cb fun(bibtex: string|nil, err: string|nil)
function M.doi(doi, cb)
  http.get("https://doi.org/" .. encode(doi),
    { accept = "application/x-bibtex" }, cb)
end

--- arXiv ids have had registered DOIs since 2022, so the same path works.
function M.arxiv(id, cb)
  M.doi("10.48550/arXiv." .. id, cb)
end

-- -------------------------------------------------------------------- isbn

--- OpenLibrary, since Crossref does not index books by ISBN.
function M.isbn(isbn, cb)
  local url = "https://openlibrary.org/api/books?bibkeys=ISBN:"
    .. isbn .. "&format=json&jscmd=data"

  http.get(url, nil, function(body, err)
    if not body then return cb(nil, err) end

    local ok, data = pcall(vim.json.decode, body)
    local item = ok and data and data["ISBN:" .. isbn]
    if not item then return cb(nil, "no book found for that ISBN") end

    local authors = {}
    for _, a in ipairs(item.authors or {}) do table.insert(authors, a.name) end
    local year = (item.publish_date or ""):match("[12]%d%d%d") or ""
    local publisher = item.publishers and item.publishers[1]
      and item.publishers[1].name or ""

    cb(table.concat({
      "@book{isbn" .. isbn .. ",",
      ("  title = {%s},"):format(item.title or ""),
      ("  author = {%s},"):format(table.concat(authors, " and ")),
      ("  year = {%s},"):format(year),
      ("  publisher = {%s},"):format(publisher),
      ("  isbn = {%s},"):format(isbn),
      "}",
    }, "\n"), nil)
  end)
end

-- ------------------------------------------------------------------ search

--- Crossref bibliographic search.
---@param query string
---@param cb fun(results: table[]|nil, err: string|nil)
function M.search(query, cb)
  local params = {
    "query.bibliographic=" .. encode(query),
    "rows=10",
    "select=" .. encode("DOI,title,author,issued,container-title,type"),
  }
  local mailto = config.get().mailto
  if mailto then table.insert(params, "mailto=" .. encode(mailto)) end

  http.get("https://api.crossref.org/works?" .. table.concat(params, "&"),
    nil, function(body, err)
      if not body then return cb(nil, err) end

      local ok, data = pcall(vim.json.decode, body)
      if not ok or not data.message then return cb(nil, "bad response from crossref") end

      local out = {}
      for _, item in ipairs(data.message.items or {}) do
        local who = "?"
        if item.author and item.author[1] then
          who = item.author[1].family or item.author[1].name or "?"
          if #item.author > 1 then who = who .. " et al." end
        end

        local year = "?"
        local parts = item.issued and item.issued["date-parts"]
        if parts and parts[1] and parts[1][1] then year = tostring(parts[1][1]) end

        table.insert(out, {
          doi = item.DOI,
          who = who,
          year = year,
          title = (item.title and item.title[1]) or "(untitled)",
          venue = (item["container-title"] and item["container-title"][1]) or "",
          kind = item.type or "",
        })
      end
      cb(out, nil)
    end)
end

-- --------------------------------------------------------------------- pdf

local DOI_PAT = "10%.%d%d%d%d+/[%-%._;%(%)/:%w]+"

--- Scan a PDF for identifiers without any external tool.
--- Reads raw bytes, which covers metadata and XMP packets. Text inside
--- compressed streams is missed, which is what pdf2doi is for.
local function scan_pdf(path)
  local fd = io.open(path, "rb")
  if not fd then return {} end
  local blob = fd:read("*a") or ""
  fd:close()

  local found, seen = {}, {}
  local function push(id)
    if id and not seen[id:lower()] then
      seen[id:lower()] = true
      table.insert(found, id)
    end
  end

  for m in blob:gmatch(DOI_PAT) do
    push((m:gsub("[%.,;:%)%]}>'\"]+$", "")))
  end
  for m in blob:gmatch("[aA]r[xX]iv[:%s]%s*(%d%d%d%d%.%d%d%d%d%d?)") do
    push("10.48550/arXiv." .. m)
  end
  return found
end

--- Extract identifiers from a PDF, preferring pdf2doi when available.
---@param path string
---@param cb fun(dois: string[]|nil, err: string|nil)
function M.pdf(path, cb)
  local opts = config.get()

  local cmd = opts.pdf2doi_cmd or "pdf2doi"
  if opts.use_pdf2doi and vim.fn.executable(cmd) == 1 then
    vim.system({ cmd, path, "-nostore" }, { text = true }, function(res)
      -- this runs in a fast event context; hop back before calling on
      vim.schedule(function()
        local out = (res.stdout or "") .. (res.stderr or "")
        local id = out:match(DOI_PAT) or out:match("arXiv%.(%d%d%d%d%.%d%d%d%d%d?)")
        if id then
          if id:match("^%d%d%d%d%.") then id = "10.48550/arXiv." .. id end
          return cb({ id }, nil)
        end
        local fallback = scan_pdf(path)
        cb(#fallback > 0 and fallback or nil,
          #fallback > 0 and nil or "no identifier found in that PDF")
      end)
    end)
    return
  end

  local found = scan_pdf(path)
  if #found == 0 then
    return cb(nil, "no identifier found. Install pdf2doi for deeper extraction.")
  end
  cb(found, nil)
end

return M
