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
