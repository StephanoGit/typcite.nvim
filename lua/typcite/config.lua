local M = {}

---@class TypciteConfig
M.defaults = {
  -- Filenames to look for, in order, walking up from the current buffer.
  bib_names = { "refs.bib", "references.bib", "bibliography.bib" },

  -- Used when no project bibliography is found. nil disables the fallback.
  global_bib = nil,

  -- Stop walking up at these markers, so a stray refs.bib in $HOME is never
  -- picked up for a project that has none.
  root_markers = { ".git", "typst.toml", ".typcite" },

  -- How a citation is written, per filetype.
  cite_format = {
    typst = "@%s",
    tex = "\\cite{%s}",
    plaintex = "\\cite{%s}",
    markdown = "[@%s]",
    quarto = "[@%s]",
    rmd = "[@%s]",
    org = "[cite:@%s]",
    default = "@%s",
  },

  -- Fields stripped from fetched entries before they are written.
  drop_fields = { "abstract", "file", "keywords", "annote", "note", "month" },

  -- author2024firstword. Set to a function(fields) -> string to override.
  key_format = nil,

  -- Shell out to pdf2doi when it is installed. Falls back to the built-in
  -- scanner otherwise. Set to an absolute path if it is not on Neovim's
  -- PATH, which differs from your shell's when nvim is launched from a GUI.
  use_pdf2doi = true,
  pdf2doi_cmd = "pdf2doi",

  -- Seconds before a network call is abandoned.
  timeout = 20,

  -- Crossref asks for a contact address so they can route you to the polite
  -- API pool. Optional, but it makes searches faster.
  mailto = nil,

  -- Directories searched for a paper's PDF, relative to the bibliography.
  -- Absolute paths and ~ are also accepted.
  pdf_dirs = { ".", "papers", "pdfs", "articles", "attachments" },

  -- How to open a PDF. nil picks `open` on macOS, `xdg-open` elsewhere.
  -- Set to a function(path) to handle it yourself.
  open_cmd = nil,

  -- Record the path in a `file` field when a citation is captured from a
  -- local PDF, so it can be reopened later.
  record_file_field = true,

  -- When no local PDF exists, look for a legal open-access copy via
  -- OpenAlex, then fall back to opening the DOI in a browser.
  online_fallback = true,

  -- Download an open-access PDF into `download_dir` instead of opening it in
  -- a browser, and record it so the next open is local. Set false to just
  -- open the url.
  download_oa = true,
  download_dir = "papers",

  -- Set to false to define your own mappings.
  default_keymaps = true,
  keymap_prefix = "<leader>c",
}

M.options = vim.deepcopy(M.defaults)

---@param opts table|nil
function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), opts or {})
  return M.options
end

function M.get()
  return M.options
end

return M
