describe("render_template", {
  it("replaces placeholders", {
    tmp <- withr::local_tempfile(
      lines = "Welcome <NAME> (@<GH_USER>) to <TEAM>!"
    )
    result <- render_template(
      tmp,
      list(
        NAME = "Ada Lovelace",
        GH_USER = "adalovelace",
        TEAM = "website"
      )
    )
    expect_identical(result, "Welcome Ada Lovelace (@adalovelace) to website!")
  })

  it("handles multiple occurrences of same placeholder", {
    tmp <- withr::local_tempfile(
      lines = "Hi <NAME>, welcome <NAME>!"
    )
    result <- render_template(tmp, list(NAME = "Ada"))
    expect_identical(result, "Hi Ada, welcome Ada!")
  })

  it("leaves unknown placeholders untouched", {
    tmp <- withr::local_tempfile(
      lines = "Hello <NAME>, your role is <ROLE>"
    )
    result <- render_template(tmp, list(NAME = "Ada"))
    expect_identical(result, "Hello Ada, your role is <ROLE>")
  })
})

describe("extract_extras", {
  it("extracts content from Extra HTML comment", {
    content <- paste(
      "Some text",
      "<!-- Extra for us",
      "- [ ] Do something special",
      "- [ ] Another task",
      "-->",
      "More text",
      sep = "\n"
    )
    extras <- extract_extras(content)
    expect_true(grepl("Do something special", extras, fixed = TRUE))
    expect_true(grepl("Another task", extras, fixed = TRUE))
  })

  it("returns NULL when no extras found", {
    expect_null(extract_extras("Just regular text"))
  })
})

describe("inject_before_second_header", {
  it("inserts extras before second ### header", {
    base <- paste(
      "### Section 1",
      "Content 1",
      "### Section 2",
      "Content 2",
      sep = "\n"
    )
    result <- inject_before_second_header(base, "- [ ] Extra task")
    lines <- strsplit(result, "\n")[[1]]

    section2_idx <- grep("^### Section 2", lines)
    extra_idx <- grep("Extra task", lines, fixed = TRUE)
    expect_lt(extra_idx, section2_idx)
  })

  it("appends if fewer than two headers", {
    base <- "### Only one header\nContent"
    result <- inject_before_second_header(base, "- [ ] Extra")
    expect_true(grepl("Extra", result, fixed = TRUE))
  })
})

describe("combine_templates", {
  it("injects extras from team template into base", {
    base <- paste(
      "### What we will do",
      "Base tasks",
      "### What you need to do",
      "Your tasks",
      sep = "\n"
    )
    team <- paste(
      "Team info",
      "<!-- Extra for us",
      "- [ ] Team-specific task",
      "-->",
      "Other team info",
      sep = "\n"
    )
    result <- combine_templates(base, team)
    expect_true(grepl("Team-specific task", result, fixed = TRUE))

    lines <- strsplit(result, "\n")[[1]]
    extra_idx <- grep("Team-specific task", lines, fixed = TRUE)
    section2_idx <- grep("^### What you need to do", lines)
    expect_lt(extra_idx, section2_idx)
  })

  it("concatenates when no extras comment", {
    base <- "Base content"
    team <- "Team content"
    result <- combine_templates(base, team)
    expect_true(grepl("Base content", result, fixed = TRUE))
    expect_true(grepl("Team content", result, fixed = TRUE))
  })
})
