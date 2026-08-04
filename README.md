# typcite.nvim

Capture a citation from anything, in one keystroke.

Paste a DOI, an arXiv id, an ISBN, a path to a PDF, or just a title you half
remember. typcite works out which it is, fetches the entry, adds it to the
right bibliography for the project you are in, and writes the citation into
your buffer in the syntax your filetype uses.

```
<leader>ca   →   10.1038/375482a0
                 ↓
                 refs.bib gains @article{flor1995phantom, ...}
                 buffer gains @flor1995phantom
```

Built for Typst, works with LaTeX, Pandoc markdown, Quarto and Org.

## Why

Existing tools each solve one part of this well.
[telescope-bibtex](https://github.com/nvim-telescope/telescope-bibtex.nvim)
picks from a bibliography you already have.
[pdf2doi](https://github.com/MicheleCotrufo/pdf2doi) gets an identifier out of
a PDF. [betterbib](https://github.com/nschloe/betterbib) and doi2bib fetch
records from the command line.

[zotcite](https://github.com/jalvesaq/zotcite) goes furthest, with Zotero
integration for Typst among other filetypes, but it assumes you have committed
to Zotero as your reference manager and needs sqlite3 alongside it. typcite
assumes a plain `.bib` file and nothing else.

None of them close the loop: getting a reference you do not yet have into the
document you are writing, without leaving the editor. That gap is the whole
point of this plugin. Where a good tool already exists, typcite calls it rather
than reimplementing it.

## Install

```lua
{
  "stephanogit/typcite.nvim",
  ft = { "typst", "tex", "markdown", "quarto" },
  opts = {},
}
```

Requires Neovim 0.10+ and `curl`.

Recommended: `pipx install pdf2doi` for PDFs whose identifier sits inside a
compressed stream, and
[telescope-ui-select](https://github.com/nvim-telescope/telescope-ui-select.nvim)
so the pickers get fuzzy search.

Run `:checkhealth typcite` to confirm everything is wired up.

## Use

| Key | Does |
| --- | --- |
| `<leader>ca` | Capture. Prompts, then detects DOI / arXiv / ISBN / PDF / title. |
| `<leader>cd` | Same, but reads the clipboard first. |
| `<leader>cc` | Pick from the current bibliography. No network. |
| `<leader>cb` | Toggle a split showing the bibliography. |

Also `:Typcite`, `:Typcite add <thing>`, `:Typcite pick`, `:Typcite bib`.

Everything network-bound is async, so a slow publisher never blocks the editor.

### Which bibliography

typcite walks up from the current buffer looking for `refs.bib`, stopping at a
`.git`, `typst.toml` or `.typcite` marker so a stray file in `$HOME` is never
picked up by accident. Each project gets its own bibliography with no config.

### Duplicates

Deduplication is by DOI, not by key. Re-adding a paper you already have returns
the existing key instead of writing a second entry. Genuine key collisions get
`b`, `c`, `d` suffixes.

## Configure

```lua
opts = {
  bib_names = { "refs.bib", "references.bib" },
  global_bib = "~/library/master.bib",   -- fallback when a project has none
  root_markers = { ".git", "typst.toml" },

  cite_format = {
    typst = "@%s",
    tex = "\\cite{%s}",
    markdown = "[@%s]",
    default = "@%s",
  },

  drop_fields = { "abstract", "file", "keywords", "note", "month" },

  -- author2024firstword by default
  key_format = function(fields)
    return fields.doi and fields.doi:gsub("[^%w]", "") or "unknown"
  end,

  mailto = "you@example.com",   -- puts Crossref calls in the polite pool
  use_pdf2doi = true,
  default_keymaps = true,
  keymap_prefix = "<leader>c",
}
```

## Test

```
nvim --headless -c "PlenaryBustedDirectory tests/ {minimal_init = 'tests/minimal_init.lua'}"
```

## License

MIT
