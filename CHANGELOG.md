# Changelog

## [Unreleased]

### Added
- `<leader>co` opens the PDF for the citation under the cursor
- Falls back to an open-access copy via OpenAlex, downloading and recording it
- Falls back again to the publisher page when no open-access copy exists

## [0.1.0]

Initial release.

- Capture from DOI, arXiv id, ISBN, PDF path, or a title, behind one mapping
- Async fetching, so a slow publisher never blocks the editor
- Project-local bibliography resolution with configurable root markers
- Deduplication by DOI rather than by key
- Filetype-aware citation syntax for Typst, LaTeX, Pandoc, Quarto and Org
- Optional pdf2doi backend with a built-in fallback scanner
- `:checkhealth typcite`
