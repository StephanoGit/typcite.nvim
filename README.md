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
  "radu/typcite.nvim",
  ft = { "typst", "tex", "markdown", "quarto" },
  opts = {},
}
```

Requires Neovim 0.10+ and `curl`.

Recommended: `pipx install pdf2doi` for PDFs whose identifier sits inside a
compressed stream, and
[telescope-ui-select](https://github.com/nvim-telescope/telescope-ui-select.nvim)
so the pickers get fuzzy search.

### Nix

The repo is a flake exposing an overlay:

```nix
{
  inputs.typcite.url = "github:stephanogit/typcite.nvim";

  # in your config
  nixpkgs.overlays = [ inputs.typcite.overlays.default ];

  programs.neovim = {
    plugins = [ pkgs.vimPlugins.typcite-nvim ];
    extraPackages = with pkgs; [
      curl
      python3Packages.pdf2doi   # optional
    ];
  };
}
```

`extraPackages` matters here. Neovim on NixOS does not inherit your shell's
PATH, so `curl` has to be put in the wrapper explicitly or nothing will
fetch. `:checkhealth typcite` reports what it can actually see.

Without flakes, `vimUtils.buildVimPlugin` with `src = fetchFromGitHub { ... }`
works the same way.

Run `:checkhealth typcite` to confirm everything is wired up.

## Use

| Key | Does |
| --- | --- |
| `<leader>ca` | Capture. Prompts, then detects DOI / arXiv / ISBN / PDF / title. |
| `<leader>cd` | Same, but reads the clipboard first. |
| `<leader>cc` | Pick from the current bibliography. No network. |
| `<leader>cb` | Toggle a split showing the bibliography. |
| `<leader>co` | Open the PDF for the citation under the cursor. |

Also `:Typcite`, `:Typcite add <thing>`, `:Typcite pick`, `:Typcite bib`.

Everything network-bound is async, so a slow publisher never blocks the editor.

### Which bibliography

typcite walks up from the current buffer looking for `refs.bib`, stopping at a
`.git`, `typst.toml` or `.typcite` marker so a stray file in `$HOME` is never
picked up by accident. Each project gets its own bibliography with no config.

### Opening the paper

`<leader>co` on a citation opens its PDF. typcite records the path when you
capture from a local file, and otherwise looks for `<key>.pdf` in `papers/`,
`pdfs/` or `articles/` next to the bibliography. So this needs no config:

```
fNIRS_Results/
  refs.bib
  main.typ
  papers/flor1995phantom.pdf
```

If there is no local copy, typcite asks OpenAlex for a legal open-access one,
downloads it into `papers/`, records it in the entry, and opens it. Next time
it is already there. No open-access copy means the publisher page opens in
your browser instead, where institutional access applies.

### Duplicates

Deduplication is by DOI, not by key. Re-adding a paper you already have returns
the existing key instead of writing a second entry. Genuine key collisions get
`b`, `c`, `d` suffixes.

## Configure

Everything below is a default. `opts = {}` is a working configuration.

```lua
opts = {
  --------------------------------------------------------------------
  -- Finding the bibliography
  --------------------------------------------------------------------

  -- Looked for in order, walking up from the current buffer.
  bib_names = { "refs.bib", "references.bib", "bibliography.bib" },

  -- Used when a project has none. nil disables the fallback.
  global_bib = nil,

  -- Stop walking up at a directory containing any of these, so a stray
  -- refs.bib in $HOME is never adopted by a project that has none.
  root_markers = { ".git", "typst.toml", ".typcite" },

  --------------------------------------------------------------------
  -- Writing the citation
  --------------------------------------------------------------------

  -- Keyed by filetype. `default` covers anything not listed.
  cite_format = {
    typst    = "@%s",
    tex      = "\\cite{%s}",
    plaintex = "\\cite{%s}",
    markdown = "[@%s]",
    quarto   = "[@%s]",
    rmd      = "[@%s]",
    org      = "[cite:@%s]",
    default  = "@%s",
  },

  -- Stripped from fetched records before writing. Publisher BibTeX often
  -- carries a full abstract, and a `file` path from someone else's machine.
  drop_fields = { "abstract", "file", "keywords", "annote", "note", "month" },

  -- nil gives author2024firstword. A function overrides it.
  key_format = nil,

  --------------------------------------------------------------------
  -- Fetching
  --------------------------------------------------------------------

  -- A contact address for Crossref and OpenAlex. This does not grant access
  -- to anything: it identifies you so they can route you to their faster
  -- pool. Optional, and worth setting.
  mailto = nil,

  -- Seconds before a network call is abandoned.
  timeout = 20,

  -- pdf2doi reads identifiers out of compressed PDF streams, which the
  -- built-in scanner cannot. Set pdf2doi_cmd to an absolute path when it is
  -- installed but Neovim cannot see it, which happens when Neovim is
  -- launched from a GUI rather than a shell.
  use_pdf2doi = true,
  pdf2doi_cmd = "pdf2doi",

  --------------------------------------------------------------------
  -- Opening papers
  --------------------------------------------------------------------

  -- Searched for <key>.pdf, relative to the bibliography. Absolute paths
  -- and ~ are accepted.
  pdf_dirs = { ".", "papers", "pdfs", "articles", "attachments" },

  -- nil picks `open` on macOS and `xdg-open` elsewhere. A function takes
  -- over entirely:
  --   open_cmd = function(path) vim.cmd("edit " .. vim.fn.fnameescape(path)) end
  open_cmd = nil,

  -- Record a `file` field when capturing from a local PDF, so it can be
  -- reopened later. Set false to keep entries free of local paths.
  record_file_field = true,

  -- With nothing on disk, ask OpenAlex for a legal open-access copy, then
  -- fall back to the publisher page. Set false to only ever look on disk.
  online_fallback = true,

  -- Save an open-access PDF and record it, rather than opening the url.
  download_oa = true,
  download_dir = "papers",

  --------------------------------------------------------------------
  -- Mappings
  --------------------------------------------------------------------

  default_keymaps = true,
  keymap_prefix = "<leader>c",
}
```

### A realistic configuration

Most people need one line, because the defaults already match a normal
project layout:

```lua
{
  "stephanogit/typcite.nvim",
  ft = { "typst", "tex", "markdown", "quarto" },
  opts = { mailto = "you@example.com" },
}
```

## Test

```
nvim --headless -c "PlenaryBustedDirectory tests/ {minimal_init = 'tests/minimal_init.lua'}"
```

## License

Apache-2.0
