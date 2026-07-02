describe("cmd_parse", {
  it("returns NULL for non-jinx comments", {
    expect_null(cmd_parse("Hello world"))
    expect_null(cmd_parse("Some random comment"))
    expect_null(cmd_parse("/notjinx help"))
  })

  it("parses help command", {
    cmd <- cmd_parse("/jinx help")
    expect_identical(cmd$action, "help")
  })

  it("parses invite command", {
    cmd <- cmd_parse("/jinx invite @octocat to website")
    expect_identical(cmd$action, "invite")
    expect_identical(cmd$username, "octocat")
    expect_identical(cmd$team, "website")
  })

  it("strips @ from username in invite", {
    cmd <- cmd_parse("/jinx invite @octocat to blog")
    expect_identical(cmd$username, "octocat")
  })

  it("handles username without @ in invite", {
    cmd <- cmd_parse("/jinx invite octocat to blog")
    expect_identical(cmd$username, "octocat")
  })

  it("returns error for malformed invite", {
    cmd <- cmd_parse("/jinx invite @octocat")
    expect_identical(cmd$action, "error")
    expect_true(grepl("Usage", cmd$message, fixed = TRUE))
  })

  it("parses offboard command", {
    cmd <- cmd_parse("/jinx offboard @octocat from website")
    expect_identical(cmd$action, "offboard")
    expect_identical(cmd$username, "octocat")
    expect_identical(cmd$team, "website")
  })

  it("returns error for malformed offboard", {
    cmd <- cmd_parse("/jinx offboard @octocat")
    expect_identical(cmd$action, "error")
    expect_true(grepl("Usage", cmd$message, fixed = TRUE))
  })

  it("parses report command with type", {
    cmd <- cmd_parse("/jinx report weekly")
    expect_identical(cmd$action, "report")
    expect_identical(cmd$type, "weekly")

    cmd <- cmd_parse("/jinx report monthly")
    expect_identical(cmd$type, "monthly")
  })

  it("defaults report type to weekly", {
    cmd <- cmd_parse("/jinx report")
    expect_identical(cmd$action, "report")
    expect_identical(cmd$type, "weekly")
  })

  it("returns error for invalid report type", {
    cmd <- cmd_parse("/jinx report yearly")
    expect_identical(cmd$action, "error")
  })

  it("parses remind command", {
    cmd <- cmd_parse("/jinx remind")
    expect_identical(cmd$action, "remind")
  })

  it("returns unknown for unrecognized commands", {
    cmd <- cmd_parse("/jinx foobar baz")
    expect_identical(cmd$action, "unknown")
    expect_true(grepl("foobar", cmd$raw, fixed = TRUE))
  })

  it("handles leading/trailing whitespace", {
    cmd <- cmd_parse("  /jinx help  ")
    expect_identical(cmd$action, "help")
  })

  it("is case-insensitive for action", {
    cmd <- cmd_parse("/jinx HELP")
    expect_identical(cmd$action, "help")

    cmd <- cmd_parse("/jinx Invite @user to website")
    expect_identical(cmd$action, "invite")
  })

  it("parses website-analytics with default period", {
    cmd <- cmd_parse("/jinx website-analytics")
    expect_equal(cmd$action, "website-analytics")
    expect_equal(cmd$period, "30d")
  })

  it("parses website-analytics with explicit period", {
    cmd <- cmd_parse("/jinx website-analytics 7d")
    expect_equal(cmd$action, "website-analytics")
    expect_equal(cmd$period, "7d")
  })

  it("returns error for invalid website-analytics period", {
    cmd <- cmd_parse("/jinx website-analytics yearly")
    expect_equal(cmd$action, "error")
  })

  it("parses chapter report", {
    cmd <- cmd_parse("/jinx report chapters")
    expect_equal(cmd$action, "report-chapters")
  })

  it("parses cfp subcommands", {
    cmd <- cmd_parse("/jinx cfp list")
    expect_equal(cmd$action, "cfp-list")

    cmd <- cmd_parse("/jinx cfp add RConf 2026-06-01 https://example.com")
    expect_equal(cmd$action, "cfp-add")
    expect_equal(cmd$conference, "RConf")

    cmd <- cmd_parse("/jinx cfp recommend RConf @speaker")
    expect_equal(cmd$action, "cfp-recommend")
    expect_equal(cmd$speaker, "speaker")
  })

  it("parses translate subcommands", {
    cmd <- cmd_parse("/jinx translate status")
    expect_equal(cmd$action, "translate-status")

    cmd <- cmd_parse("/jinx translate validate es")
    expect_equal(cmd$action, "translate-validate")
    expect_equal(cmd$language, "es")
  })

  it("parses events commands", {
    cmd <- cmd_parse("/jinx events oslo")
    expect_equal(cmd$action, "events")
    expect_equal(cmd$chapter, "oslo")

    cmd <- cmd_parse("/jinx events sync")
    expect_equal(cmd$action, "events-sync")
  })

  it("parses contributor subcommands", {
    cmd <- cmd_parse("/jinx contributors")
    expect_equal(cmd$action, "contributors-list")

    cmd <- cmd_parse("/jinx contributors org")
    expect_equal(cmd$action, "contributors-org")

    cmd <- cmd_parse("/jinx contributors update jinx")
    expect_equal(cmd$action, "contributors-update")
    expect_equal(cmd$repo, "jinx")
  })

  it("parses a poll create command with a multi-word title", {
    cmd <- cmd_parse(paste(
      "/jinx poll create Summer planning days=2026-07-01,2026-07-02",
      "from=09:00 to=17:00 slot=30 tz=Europe/Oslo"
    ))
    expect_equal(cmd$action, "poll-create")
    expect_equal(cmd$title, "Summer planning")
    expect_equal(cmd$days, c("2026-07-01", "2026-07-02"))
    expect_equal(cmd$from, "09:00")
    expect_equal(cmd$to, "17:00")
    expect_equal(cmd$slot, 30L)
    expect_equal(cmd$tz, "Europe/Oslo")
    expect_true(cmd$public)
  })

  it("defaults poll tz to UTC, kind to dates, and public to TRUE", {
    cmd <- cmd_parse(
      "/jinx poll create Sync days=2026-07-01 from=09:00 to=17:00 slot=30"
    )
    expect_equal(cmd$tz, "UTC")
    expect_equal(cmd$kind, "dates")
    expect_true(cmd$public)
  })

  it("parses a weekdays poll", {
    cmd <- cmd_parse(paste(
      "/jinx poll create Standup days=mon,wed,fri from=09:00",
      "to=10:00 slot=15 kind=weekdays"
    ))
    expect_equal(cmd$action, "poll-create")
    expect_equal(cmd$kind, "weekdays")
    expect_equal(cmd$days, c("mon", "wed", "fri"))
  })

  it("rejects an unknown poll kind", {
    cmd <- cmd_parse(paste(
      "/jinx poll create Sync days=2026-07-01 from=09:00",
      "to=17:00 slot=30 kind=fortnightly"
    ))
    expect_equal(cmd$action, "error")
    expect_match(cmd$message, "kind")
  })

  it("honours public=false in a poll create command", {
    cmd <- cmd_parse(paste(
      "/jinx poll create Sync days=2026-07-01 from=09:00",
      "to=17:00 slot=30 public=false"
    ))
    expect_false(cmd$public)
  })

  it("rejects stray tokens between poll options", {
    cmd <- cmd_parse(paste(
      "/jinx poll create Sync days=2026-07-01 oops from=09:00",
      "to=17:00 slot=30"
    ))
    expect_equal(cmd$action, "error")
    expect_match(cmd$message, "oops")
  })

  it("rejects an empty days value", {
    cmd <- cmd_parse(
      "/jinx poll create Sync days= from=09:00 to=17:00 slot=30"
    )
    expect_equal(cmd$action, "error")
    expect_match(cmd$message, "days")
  })

  it("errors on a poll create command missing required fields", {
    cmd <- cmd_parse("/jinx poll create Sync from=09:00 to=17:00")
    expect_equal(cmd$action, "error")
    expect_match(cmd$message, "Usage")
  })

  it("errors on a poll create command with no title", {
    cmd <- cmd_parse(
      "/jinx poll create days=2026-07-01 from=09:00 to=17:00 slot=30"
    )
    expect_equal(cmd$action, "error")
  })

  it("parses a poll best command", {
    cmd <- cmd_parse("/jinx poll best abc123")
    expect_equal(cmd$action, "poll-best")
    expect_equal(cmd$id, "abc123")
  })

  it("rejects a poll best id that could manipulate the URL", {
    cmd <- cmd_parse("/jinx poll best ../../admin")
    expect_equal(cmd$action, "error")
    expect_match(cmd$message, "Invalid poll id")
  })

  it("errors on an unknown poll subcommand", {
    cmd <- cmd_parse("/jinx poll frobnicate")
    expect_equal(cmd$action, "error")
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

describe("cmd_execute", {
  it("returns help text for help command", {
    cmd <- list(action = "help")
    result <- cmd_execute(cmd)
    expect_type(result, "character")
    expect_true(grepl("jinx", result, ignore.case = TRUE))
  })

  it("returns error message for error command", {
    cmd <- list(action = "error", message = "bad input")
    result <- cmd_execute(cmd)
    expect_equal(result, "bad input")
  })

  it("returns unknown message for unknown command", {
    cmd <- list(action = "unknown", raw = "foobar")
    result <- cmd_execute(cmd)
    expect_true(grepl("Unknown command", result))
    expect_true(grepl("foobar", result))
  })

  it("returns NULL for NULL command", {
    result <- cmd_execute(NULL)
    expect_null(result)
  })
})
