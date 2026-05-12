describe("parse_cfp_body", {
  it("extracts metadata from CFP issue body", {
    body <- paste0(
      "Some text\n\n",
      "<!-- cfp-meta\n",
      "conference: posit::conf\n",
      "deadline: 2024-06-15\n",
      "url: https://posit.co/conference/cfp\n",
      "-->"
    )
    result <- parse_cfp_body(body)
    expect_identical(result$conference, "posit::conf")
    expect_identical(result$deadline, "2024-06-15")
    expect_identical(result$url, "https://posit.co/conference/cfp")
  })

  it("returns empty list when no metadata", {
    expect_identical(parse_cfp_body("No metadata here"), list())
  })

  it("handles body with colons in URL", {
    body <- "<!-- cfp-meta\nurl: https://example.com:8080/cfp\n-->"
    result <- parse_cfp_body(body)
    expect_identical(result$url, "https://example.com:8080/cfp")
  })
})

describe("extract_field", {
  it("extracts a bold field value", {
    body <- "**Speaker**: @octocat\n**Expertise**: R, statistics"
    expect_identical(extract_field(body, "Speaker"), "@octocat")
    expect_identical(extract_field(body, "Expertise"), "R, statistics")
  })

  it("returns NULL for missing field", {
    expect_null(extract_field("no fields here", "Speaker"))
  })
})

describe("cfp command parsing", {
  it("parses /jinx cfp list", {
    cmd <- parse_command("/jinx cfp list")
    expect_identical(cmd$action, "cfp-list")
  })

  it("parses /jinx cfp add", {
    cmd <- parse_command(
      "/jinx cfp add posit::conf 2024-06-15 https://posit.co/cfp"
    )
    expect_identical(cmd$action, "cfp-add")
    expect_identical(cmd$conference, "posit::conf")
    expect_identical(cmd$deadline, "2024-06-15")
    expect_identical(cmd$url, "https://posit.co/cfp")
  })

  it("parses /jinx cfp recommend", {
    cmd <- parse_command("/jinx cfp recommend posit::conf @octocat")
    expect_identical(cmd$action, "cfp-recommend")
    expect_identical(cmd$conference, "posit::conf")
    expect_identical(cmd$speaker, "octocat")
  })

  it("returns error for bare cfp", {
    cmd <- parse_command("/jinx cfp")
    expect_identical(cmd$action, "error")
  })

  it("returns error for cfp add with missing args", {
    cmd <- parse_command("/jinx cfp add posit::conf")
    expect_identical(cmd$action, "error")
  })
})
