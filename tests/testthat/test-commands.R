describe("parse_command", {
  it("returns NULL for non-jinx comments", {
    expect_null(parse_command("Hello world"))
    expect_null(parse_command("Some random comment"))
    expect_null(parse_command("/notjinx help"))
  })

  it("parses help command", {
    cmd <- parse_command("/jinx help")
    expect_identical(cmd$action, "help")
  })

  it("parses invite command", {
    cmd <- parse_command("/jinx invite @octocat to website")
    expect_identical(cmd$action, "invite")
    expect_identical(cmd$username, "octocat")
    expect_identical(cmd$team, "website")
  })

  it("strips @ from username in invite", {
    cmd <- parse_command("/jinx invite @octocat to blog")
    expect_identical(cmd$username, "octocat")
  })

  it("handles username without @ in invite", {
    cmd <- parse_command("/jinx invite octocat to blog")
    expect_identical(cmd$username, "octocat")
  })

  it("returns error for malformed invite", {
    cmd <- parse_command("/jinx invite @octocat")
    expect_identical(cmd$action, "error")
    expect_true(grepl("Usage", cmd$message, fixed = TRUE))
  })

  it("parses offboard command", {
    cmd <- parse_command("/jinx offboard @octocat from website")
    expect_identical(cmd$action, "offboard")
    expect_identical(cmd$username, "octocat")
    expect_identical(cmd$team, "website")
  })

  it("returns error for malformed offboard", {
    cmd <- parse_command("/jinx offboard @octocat")
    expect_identical(cmd$action, "error")
    expect_true(grepl("Usage", cmd$message, fixed = TRUE))
  })

  it("parses report command with type", {
    cmd <- parse_command("/jinx report weekly")
    expect_identical(cmd$action, "report")
    expect_identical(cmd$type, "weekly")

    cmd <- parse_command("/jinx report monthly")
    expect_identical(cmd$type, "monthly")
  })

  it("defaults report type to weekly", {
    cmd <- parse_command("/jinx report")
    expect_identical(cmd$action, "report")
    expect_identical(cmd$type, "weekly")
  })

  it("returns error for invalid report type", {
    cmd <- parse_command("/jinx report yearly")
    expect_identical(cmd$action, "error")
  })

  it("parses remind command", {
    cmd <- parse_command("/jinx remind")
    expect_identical(cmd$action, "remind")
  })

  it("returns unknown for unrecognized commands", {
    cmd <- parse_command("/jinx foobar baz")
    expect_identical(cmd$action, "unknown")
    expect_true(grepl("foobar", cmd$raw, fixed = TRUE))
  })

  it("handles leading/trailing whitespace", {
    cmd <- parse_command("  /jinx help  ")
    expect_identical(cmd$action, "help")
  })

  it("is case-insensitive for action", {
    cmd <- parse_command("/jinx HELP")
    expect_identical(cmd$action, "help")

    cmd <- parse_command("/jinx Invite @user to website")
    expect_identical(cmd$action, "invite")
  })

  it("parses website-analytics with default period", {
    cmd <- parse_command("/jinx website-analytics")
    expect_equal(cmd$action, "website-analytics")
    expect_equal(cmd$period, "30d")
  })

  it("parses website-analytics with explicit period", {
    cmd <- parse_command("/jinx website-analytics 7d")
    expect_equal(cmd$action, "website-analytics")
    expect_equal(cmd$period, "7d")
  })

  it("returns error for invalid website-analytics period", {
    cmd <- parse_command("/jinx website-analytics yearly")
    expect_equal(cmd$action, "error")
  })

  it("parses chapter report", {
    cmd <- parse_command("/jinx report chapters")
    expect_equal(cmd$action, "report-chapters")
  })

  it("parses cfp subcommands", {
    cmd <- parse_command("/jinx cfp list")
    expect_equal(cmd$action, "cfp-list")

    cmd <- parse_command("/jinx cfp add RConf 2026-06-01 https://example.com")
    expect_equal(cmd$action, "cfp-add")
    expect_equal(cmd$conference, "RConf")

    cmd <- parse_command("/jinx cfp recommend RConf @speaker")
    expect_equal(cmd$action, "cfp-recommend")
    expect_equal(cmd$speaker, "speaker")
  })

  it("parses translate subcommands", {
    cmd <- parse_command("/jinx translate status")
    expect_equal(cmd$action, "translate-status")

    cmd <- parse_command("/jinx translate validate es")
    expect_equal(cmd$action, "translate-validate")
    expect_equal(cmd$language, "es")
  })

  it("parses events commands", {
    cmd <- parse_command("/jinx events oslo")
    expect_equal(cmd$action, "events")
    expect_equal(cmd$chapter, "oslo")

    cmd <- parse_command("/jinx events sync")
    expect_equal(cmd$action, "events-sync")
  })

  it("parses contributor subcommands", {
    cmd <- parse_command("/jinx contributors")
    expect_equal(cmd$action, "contributors-list")

    cmd <- parse_command("/jinx contributors org")
    expect_equal(cmd$action, "contributors-org")

    cmd <- parse_command("/jinx contributors update jinx")
    expect_equal(cmd$action, "contributors-update")
    expect_equal(cmd$repo, "jinx")
  })
})

describe("normalize_command", {
  it("normalizes multi-word phrases to single actions", {
    expect_equal(
      normalize_command(c("generate", "website", "analytics", "7d")),
      c("website-analytics", "7d")
    )
    expect_equal(
      normalize_command(c("website", "analytics")),
      "website-analytics"
    )
    expect_equal(
      normalize_command(c("check", "blog", "links")),
      "blog-check-links"
    )
    expect_equal(
      normalize_command(c("validate", "directory")),
      "validate-directory"
    )
    expect_equal(
      normalize_command(c("remind", "stale")),
      "remind"
    )
  })

  it("passes through unrecognized commands unchanged", {
    expect_equal(
      normalize_command(c("help")),
      "help"
    )
    expect_equal(
      normalize_command(c("invite", "@user", "to", "blog")),
      c("invite", "@user", "to", "blog")
    )
  })

  it("is case-insensitive", {
    expect_equal(
      normalize_command(c("Generate", "Website", "Analytics")),
      "website-analytics"
    )
  })
})

describe("execute_command", {
  it("returns help text for help command", {
    cmd <- list(action = "help")
    result <- execute_command(cmd)
    expect_type(result, "character")
    expect_true(grepl("jinx", result, ignore.case = TRUE))
  })

  it("returns error message for error command", {
    cmd <- list(action = "error", message = "bad input")
    result <- execute_command(cmd)
    expect_equal(result, "bad input")
  })

  it("returns unknown message for unknown command", {
    cmd <- list(action = "unknown", raw = "foobar")
    result <- execute_command(cmd)
    expect_true(grepl("Unknown command", result))
    expect_true(grepl("foobar", result))
  })

  it("returns NULL for NULL command", {
    result <- execute_command(NULL)
    expect_null(result)
  })
})
