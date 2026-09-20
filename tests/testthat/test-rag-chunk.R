describe("strip_frontmatter", {
  it("extracts YAML frontmatter and body", {
    md <- "---\ntitle: Hello\ndate: 2024-01-02\n---\nBody text."
    parts <- strip_frontmatter(md)
    expect_identical(parts$frontmatter$title, "Hello")
    expect_identical(parts$body, "Body text.")
  })

  it("returns empty frontmatter when missing", {
    parts <- strip_frontmatter("Just body.")
    expect_identical(parts$body, "Just body.")
    expect_identical(parts$frontmatter, list())
  })

  it("handles malformed frontmatter without crashing", {
    parts <- strip_frontmatter("---\nnot: [yaml\n---\nbody")
    expect_identical(parts$body, "body")
  })
})

describe("split_by_sections", {
  it("splits on H1 and H2 only, ignoring H3", {
    body <- "# A\nintro\n## B\nb-body\n### C\nc-body\n## D\nd-body"
    sections <- split_by_sections(body)
    headings <- vapply(sections, function(s) s$heading, character(1))
    expect_identical(headings, c("A", "B", "D"))
  })

  it("captures leading content before first heading", {
    sections <- split_by_sections("preamble\n# A\nbody")
    expect_identical(sections[[1]]$heading, "")
    expect_match(sections[[1]]$body, "preamble")
  })
})

describe("split_to_target", {
  it("returns input unchanged when under target", {
    expect_identical(split_to_target("short text", 100), "short text")
  })

  it("packs paragraphs up to target", {
    para <- strrep("x ", 50)
    text <- paste(rep(trimws(para), 5), collapse = "\n\n")
    out <- split_to_target(text, 200)
    expect_true(length(out) > 1L)
    expect_true(all(nchar(out) <= 250L))
  })

  it("hard-splits paragraphs longer than target", {
    huge <- strrep("a", 500)
    out <- split_to_target(huge, 100)
    expect_true(length(out) >= 5L)
  })
})

describe("parse_unix_date", {
  it("returns NULL for empty inputs", {
    expect_null(parse_unix_date(NULL))
    expect_null(parse_unix_date(""))
    expect_null(parse_unix_date(0))
  })

  it("returns NULL for empty JSON objects parsed as list()", {
    expect_null(parse_unix_date(list()))
  })

  it("returns NULL for non-character, non-numeric inputs (e.g. named lists)", {
    expect_null(parse_unix_date(list(x = 1)))
  })

  it("returns NULL for NA without erroring", {
    expect_null(parse_unix_date(NA))
    expect_null(parse_unix_date(NA_character_))
  })

  it("returns NULL for a malformed date string without erroring", {
    expect_null(parse_unix_date("not-a-date"))
    expect_null(parse_unix_date("2026-13-99T99:99"))
  })

  it("parses ISO 8601 to unix seconds", {
    expect_identical(parse_unix_date("2024-01-02T00:00:00Z"), 1704153600L)
  })

  it("passes through numeric unix seconds", {
    expect_identical(parse_unix_date(1704153600), 1704153600L)
  })
})

describe("chunk_markdown", {
  it("emits one chunk per section above min_chars", {
    body <- paste0(
      "# Section A\n",
      strrep("alpha ", 60),
      "\n\n## Section B\n",
      strrep("beta ", 60)
    )
    chunks <- chunk_markdown(
      body,
      meta = list(
        repo = "r/x",
        path = "x",
        url = "u",
        fallback_title = "T"
      ),
      min_chars = 50
    )
    expect_length(chunks, 2L)
    expect_identical(chunks[[1]]$heading, "Section A")
    expect_identical(chunks[[2]]$heading, "Section B")
    expect_identical(chunks[[1]]$title, "T")
  })

  it("uses frontmatter title over fallback", {
    md <- "---\ntitle: From Front\n---\n# H\n"
    chunks <- chunk_markdown(
      paste0(md, strrep("x ", 200)),
      meta = list(
        repo = "r",
        path = "p",
        url = "u",
        fallback_title = "fallback"
      )
    )
    expect_identical(chunks[[1]]$title, "From Front")
  })

  it("drops sections shorter than min_chars", {
    md <- "# Tiny\nhi\n\n# Bigger\n"
    chunks <- chunk_markdown(
      paste0(md, strrep("x ", 200)),
      meta = list(repo = "r", path = "p", url = "u", fallback_title = "T"),
      min_chars = 200
    )
    headings <- vapply(chunks, function(c) c$heading, character(1))
    expect_false("Tiny" %in% headings)
  })
})
