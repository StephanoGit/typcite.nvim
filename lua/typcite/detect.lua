local M = {}

--- Classify a captured string.
---@param raw string
---@return string kind  one of doi|arxiv|isbn|pdf|title
---@return string value normalised payload for that kind
function M.classify(raw)
  local s = vim.trim(raw or "")
  s = s:gsub("^<", ""):gsub(">$", "")

  -- A readable pdf on disk. Only run expand() on something already shaped
  -- like a path: expand("%") returns the current filename, and a search
  -- title containing % or # would otherwise be silently rewritten.
  if s:lower():match("%.pdf$") then
    -- Expand only a leading ~. Running expand() over the whole string would
    -- also try to interpret a ~ in the middle of a path, and iCloud Drive
    -- paths contain them: .../Mobile Documents/com~apple~CloudDocs/...
    local p = s
    if p:sub(1, 1) == "~" then
      p = vim.fn.expand("~") .. p:sub(2)
    end
    p = vim.fn.fnamemodify(p, ":p")
    if vim.uv.fs_stat(p) then return "pdf", p end
  end

  -- arXiv, in any of the forms people paste
  local arx = s:match("[aA][rR][xX][iI][vV][:/%s]%s*(%d%d%d%d%.%d%d%d%d%d?)")
    or s:match("arxiv%.org/abs/(%d%d%d%d%.%d%d%d%d%d?)")
    or s:match("arxiv%.org/pdf/(%d%d%d%d%.%d%d%d%d%d?)")
  if arx then return "arxiv", arx end
  if s:match("^%d%d%d%d%.%d%d%d%d%d?[vV]?%d*$") then
    return "arxiv", s:match("^(%d%d%d%d%.%d%d%d%d%d?)")
  end

  -- DOI, bare or inside a url
  local doi = s:match("(10%.%d%d%d%d+/[^%s]+)")
  if doi then
    doi = doi:gsub("[%.,;:%)%]}>'\"]+$", "")
    while select(2, doi:gsub("%(", "")) < select(2, doi:gsub("%)", "")) do
      doi = doi:sub(1, doi:find("%)[^%)]*$") - 1)
    end
    return "doi", doi
  end

  -- ISBN 10 or 13, hyphens optional
  local digits = s:gsub("[%s%-]", "")
  if digits:match("^%d%d%d%d%d%d%d%d%d[%dxX]$") or digits:match("^97[89]%d%d%d%d%d%d%d%d%d%d$") then
    return "isbn", digits
  end

  return "title", s
end

return M
