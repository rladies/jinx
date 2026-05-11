describe("format_duration", {
  it("formats seconds only", {
    expect_equal(format_duration(45), "45s")
  })

  it("formats minutes and seconds", {
    expect_equal(format_duration(125), "2m 5s")
  })

  it("handles zero", {
    expect_equal(format_duration(0), "0s")
  })

  it("handles NULL and NA", {
    expect_equal(format_duration(NULL), "0s")
    expect_equal(format_duration(NA), "0s")
  })
})

describe("format_website_analytics", {
  it("formats complete analytics data into markdown", {
    analytics <- list(
      site_id = "rladies.org",
      period = "30d",
      aggregate = list(results = list(
        visitors = list(value = 1250),
        pageviews = list(value = 3400),
        bounce_rate = list(value = 42),
        visit_duration = list(value = 185)
      )),
      timeseries = list(results = list(
        list(date = "2024-01-01", visitors = 40L, pageviews = 100L),
        list(date = "2024-01-02", visitors = 55L, pageviews = 130L),
        list(date = "2024-01-03", visitors = 38L, pageviews = 90L)
      )),
      top_pages = list(results = list(
        list(page = "/", visitors = 800L, pageviews = 1200L),
        list(page = "/about", visitors = 200L, pageviews = 300L)
      )),
      top_sources = list(results = list(
        list(source = "Google", visitors = 500L),
        list(source = "Twitter", visitors = 300L)
      ))
    )

    result <- format_website_analytics(analytics)
    expect_true(grepl("Website Analytics", result))
    expect_true(grepl("rladies.org", result))
    expect_true(grepl("1250", result))
    expect_true(grepl("3400", result))
    expect_true(grepl("42%", result))
    expect_true(grepl("3m 5s", result))
    expect_true(grepl("/about", result))
    expect_true(grepl("Google", result))
    expect_true(grepl("Twitter", result))
  })

  it("handles empty timeseries", {
    analytics <- list(
      site_id = "rladies.org",
      period = "7d",
      aggregate = list(results = list(
        visitors = list(value = 0),
        pageviews = list(value = 0),
        bounce_rate = list(value = 0),
        visit_duration = list(value = 0)
      )),
      timeseries = list(results = list()),
      top_pages = list(results = list()),
      top_sources = list(results = list())
    )

    result <- format_website_analytics(analytics)
    expect_true(grepl("No timeseries data", result))
    expect_true(grepl("No page data", result))
    expect_true(grepl("No referral data", result))
  })

  it("handles NULL source as Direct", {
    analytics <- list(
      site_id = "rladies.org",
      period = "7d",
      aggregate = list(results = list(
        visitors = list(value = 10),
        pageviews = list(value = 20),
        bounce_rate = list(value = 50),
        visit_duration = list(value = 30)
      )),
      timeseries = list(results = list()),
      top_pages = list(results = list()),
      top_sources = list(results = list(
        list(source = NULL, visitors = 10L)
      ))
    )

    result <- format_website_analytics(analytics)
    expect_true(grepl("Direct / None", result))
  })
})

describe("parse_website_analytics_command", {
  it("parses /jinx website-analytics with default period", {
    cmd <- parse_command("/jinx website-analytics")
    expect_equal(cmd$action, "website-analytics")
    expect_equal(cmd$period, "30d")
  })

  it("parses /jinx website-analytics with specified period", {
    cmd <- parse_command("/jinx website-analytics 7d")
    expect_equal(cmd$action, "website-analytics")
    expect_equal(cmd$period, "7d")

    cmd <- parse_command("/jinx website-analytics 12mo")
    expect_equal(cmd$period, "12mo")
  })

  it("returns error for invalid period", {
    cmd <- parse_command("/jinx website-analytics 3d")
    expect_equal(cmd$action, "error")
    expect_true(grepl("period", cmd$message))
  })

  it("parses natural language: /jinx generate website analytics", {
    cmd <- parse_command("/jinx generate website analytics")
    expect_equal(cmd$action, "website-analytics")
    expect_equal(cmd$period, "30d")
  })

  it("parses natural language with period", {
    cmd <- parse_command("/jinx generate website analytics 7d")
    expect_equal(cmd$action, "website-analytics")
    expect_equal(cmd$period, "7d")
  })
})

describe("format_website_slack", {
  it("formats a Slack summary with key metrics", {
    report_data <- list(
      analytics = list(
        site_id = "rladies.org",
        period = "30d",
        aggregate = list(results = list(
          visitors = list(value = 1250),
          pageviews = list(value = 3400),
          bounce_rate = list(value = 42),
          visit_duration = list(value = 185)
        )),
        timeseries = list(results = list(
          list(date = "2024-01-01", visitors = 40L, pageviews = 100L),
          list(date = "2024-01-02", visitors = 55L, pageviews = 130L)
        )),
        top_pages = list(results = list(
          list(page = "/", visitors = 800L, pageviews = 1200L),
          list(page = "/about", visitors = 200L, pageviews = 300L),
          list(page = "/events", visitors = 100L, pageviews = 150L)
        ))
      ),
      markdown = "full report"
    )

    result <- format_website_slack(report_data, "https://github.com/issue/1")
    expect_true(grepl("rladies.org", result))
    expect_true(grepl("1250", result))
    expect_true(grepl("3400", result))
    expect_true(grepl("42%", result))
    expect_true(grepl("Top pages", result))
    expect_true(grepl("/about", result))
    expect_true(grepl("View full report", result))
  })

  it("handles empty timeseries gracefully", {
    report_data <- list(
      analytics = list(
        site_id = "rladies.org",
        period = "7d",
        aggregate = list(results = list(
          visitors = list(value = 0),
          pageviews = list(value = 0),
          bounce_rate = list(value = 0),
          visit_duration = list(value = 0)
        )),
        timeseries = list(results = list()),
        top_pages = list(results = list())
      ),
      markdown = "empty"
    )

    result <- format_website_slack(report_data, "https://github.com/issue/2")
    expect_true(grepl("rladies.org", result))
    expect_false(grepl("Top pages", result))
  })
})

describe("format_analytics_slack", {
  it("formats a Slack summary for org analytics", {
    dashboard_data <- list(
      trends = data.frame(
        month = c("2024-01", "2024-02"),
        total_commits = c(15L, 23L),
        change = c(NA_real_, 53.3),
        sparkline = c("\u2581", "\u2588"),
        stringsAsFactors = FALSE
      ),
      growth = data.frame(
        month = c("2024-01", "2024-02"),
        new_contributors = c(5L, 3L),
        total_contributors = c(5L, 8L),
        active_repos = c(0L, 0L),
        stringsAsFactors = FALSE
      ),
      markdown = "full report"
    )

    result <- format_analytics_slack(dashboard_data, "https://github.com/issue/3")
    expect_true(grepl("Analytics Dashboard", result))
    expect_true(grepl("38", result))
    expect_true(grepl("23", result))
    expect_true(grepl("8", result))
    expect_true(grepl("3 new", result))
    expect_true(grepl("View full report", result))
  })
})

describe("slack_analytics_channel", {
  it("returns NULL when env var is not set", {
    withr::with_envvar(c(SLACK_ANALYTICS_CHANNEL = ""), {
      expect_null(slack_analytics_channel())
    })
  })

  it("returns channel name when set", {
    withr::with_envvar(c(SLACK_ANALYTICS_CHANNEL = "team-analytics"), {
      expect_equal(slack_analytics_channel(), "team-analytics")
    })
  })
})

describe("normalize_command", {
  it("collapses multi-word phrases to canonical actions", {
    expect_equal(normalize_command(c("generate", "report", "weekly")), c("report", "weekly"))
    expect_equal(normalize_command(c("check", "blog", "links")), "blog-check-links")
    expect_equal(normalize_command(c("validate", "directory")), "validate-directory")
    expect_equal(normalize_command(c("setup", "chapter", "oslo", "norway")), c("chapter-setup", "oslo", "norway"))
  })

  it("passes through unrecognized phrases unchanged", {
    expect_equal(normalize_command(c("invite", "@user", "to", "blog")), c("invite", "@user", "to", "blog"))
    expect_equal(normalize_command("help"), "help")
  })

  it("matches longest phrase first", {
    cmd <- normalize_command(c("generate", "website", "analytics", "6mo"))
    expect_equal(cmd, c("website-analytics", "6mo"))

    cmd2 <- normalize_command(c("website", "analytics"))
    expect_equal(cmd2, "website-analytics")
  })
})
