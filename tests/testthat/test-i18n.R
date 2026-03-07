describe("translate_template", {
  it("returns English template when language is en", {
    withr::local_envvar(list(R_TESTS = ""))
    base_path <- system.file("templates", "slack-invite.md", package = "jinx")
    skip_if(!nzchar(base_path), "jinx not installed")

    result <- translate_template(
      "slack-invite.md",
      language = "en",
      variables = list()
    )
    expect_true(nchar(result) > 0)
    expect_true(grepl("Slack", result))
  })

  it("falls back to English when translation is missing", {
    result <- translate_template(
      "slack-invite.md",
      language = "xx",
      variables = list()
    )
    expect_true(grepl("Slack", result))
  })
})

describe("list_supported_languages", {
  it("returns a data frame with expected columns", {
    result <- list_supported_languages()
    expect_s3_class(result, "data.frame")
    expect_true(all(c("code", "name", "native_name", "direction") %in% names(result)))
    expect_true(nrow(result) > 0)
    expect_true("en" %in% result$code)
  })
})

describe("extract_placeholder_keys", {
  it("extracts placeholder keys from template content", {
    path <- tempfile(fileext = ".md")
    writeLines("Hello <NAME>, welcome to <TEAM>!", path)
    on.exit(unlink(path))

    result <- extract_placeholder_keys(path)
    expect_equal(sort(result), c("NAME", "TEAM"))
  })

  it("returns empty for no placeholders", {
    path <- tempfile(fileext = ".md")
    writeLines("No placeholders here.", path)
    on.exit(unlink(path))

    result <- extract_placeholder_keys(path)
    expect_length(result, 0)
  })

  it("deduplicates repeated keys", {
    path <- tempfile(fileext = ".md")
    writeLines("<NAME> said hi to <NAME>", path)
    on.exit(unlink(path))

    result <- extract_placeholder_keys(path)
    expect_equal(result, "NAME")
  })
})

describe("check_translation_coverage", {
  it("returns coverage data frame", {
    result <- check_translation_coverage()
    expect_s3_class(result, "data.frame")
    expect_true(all(c("language", "total_templates", "translated", "coverage_pct") %in% names(result)))
  })
})

describe("translate command parsing", {
  it("parses /jinx translate status", {
    cmd <- parse_command("/jinx translate status")
    expect_equal(cmd$action, "translate-status")
  })

  it("parses /jinx translate validate es", {
    cmd <- parse_command("/jinx translate validate es")
    expect_equal(cmd$action, "translate-validate")
    expect_equal(cmd$language, "es")
  })

  it("parses /jinx translate validate without language", {
    cmd <- parse_command("/jinx translate validate")
    expect_equal(cmd$action, "translate-validate")
    expect_null(cmd$language)
  })

  it("returns error for bare translate", {
    cmd <- parse_command("/jinx translate")
    expect_equal(cmd$action, "error")
  })
})
