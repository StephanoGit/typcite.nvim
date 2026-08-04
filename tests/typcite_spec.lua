-- Run with: nvim --headless -c "PlenaryBustedDirectory tests/"
local bib = require("typcite.bib")
local detect = require("typcite.detect")
local insert = require("typcite.insert")

describe("bib.parse", function()
  local sample = [[
@article{Flor_1995,
  title={Phantom-limb pain as a perceptual correlate of cortical reorganization},
  DOI={10.1038/375482a0},
  author={Flor, Herta and Elbert, Thomas},
  year={1995},
  abstract={Nested {braces} inside here, and a comma.}
}

@inproceedings{pena2024,
  title = "Ascending Somatosensory Pathways",
  author = {Ana-Maria Pena Gomez and Rui Loureiro},
  year = {2024}
}
]]

  it("finds every entry", function()
    assert.equals(2, #bib.parse(sample))
  end)

  it("keeps nested braces intact", function()
    local e = bib.parse(sample)[1]
    assert.equals("Nested {braces} inside here, and a comma.", e.fields.abstract)
  end)

  it("handles quoted values", function()
    local e = bib.parse(sample)[2]
    assert.equals("Ascending Somatosensory Pathways", e.fields.title)
  end)

  it("lowercases field names", function()
    assert.equals("10.1038/375482a0", bib.parse(sample)[1].fields.doi)
  end)

  it("ignores @comment and @string", function()
    assert.equals(0, #bib.parse('@comment{ignore me}\n@string{x = "y"}'))
  end)
end)

describe("bib key generation", function()
  it("builds author+year+word", function()
    assert.equals("flor1995phantom", bib.make_key({
      author = "Flor, Herta and Elbert, Thomas",
      year = "1995",
      title = "Phantom-limb pain as a perceptual correlate",
    }, {}))
  end)

  it("folds accents in surnames", function()
    assert.equals("gomez", bib.first_surname("Ana-Maria Pena Gomez and Rui Loureiro"))
  end)

  it("skips stopwords in the title", function()
    assert.equals("ascending", bib.title_word("The Role of Ascending Pathways"))
  end)

  it("suffixes collisions", function()
    local fields = { author = "Flor, H", year = "1995", title = "Phantom limb" }
    assert.equals("flor1995phantomb", bib.make_key(fields, { flor1995phantom = true }))
  end)

  it("falls back to date for the year", function()
    assert.equals("2024", bib.year({ date = "2024-03-01" }))
  end)

  it("survives a missing author", function()
    assert.equals("anon", bib.first_surname(""))
  end)
end)

describe("detect.classify", function()
  local cases = {
    { "10.1038/375482a0",                  "doi",   "10.1038/375482a0" },
    { "https://doi.org/10.1038/375482a0",  "doi",   "10.1038/375482a0" },
    { "10.1038/375482a0.",                 "doi",   "10.1038/375482a0" },
    { "arXiv:2401.12345",                  "arxiv", "2401.12345" },
    { "https://arxiv.org/abs/2312.09876",  "arxiv", "2312.09876" },
    { "2401.12345",                        "arxiv", "2401.12345" },
    { "978-0-13-235088-4",                 "isbn",  "9780132350884" },
    { "phantom limb cortical",             "title", "phantom limb cortical" },
  }

  for _, case in ipairs(cases) do
    it("classifies " .. case[1], function()
      local kind, value = detect.classify(case[1])
      assert.equals(case[2], kind)
      assert.equals(case[3], value)
    end)
  end
end)

describe("insert.format_for", function()
  it("uses typst syntax", function()
    assert.equals("@key", insert.format_for("typst"):format("key"))
  end)

  it("uses latex syntax", function()
    assert.equals("\\cite{key}", insert.format_for("tex"):format("key"))
  end)

  it("uses pandoc syntax for markdown", function()
    assert.equals("[@key]", insert.format_for("markdown"):format("key"))
  end)

  it("falls back for unknown filetypes", function()
    assert.equals("@key", insert.format_for("nonsense"):format("key"))
  end)
end)

describe("bib.render", function()
  it("round trips", function()
    local out = bib.render("article", "test2024thing",
      { title = "A Title", year = "2024", author = "Doe, Jane" })
    local back = bib.parse(out)[1]
    assert.equals("test2024thing", back.key)
    assert.equals("A Title", back.fields.title)
  end)
end)
