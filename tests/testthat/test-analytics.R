describe("compute_sparkline", {
  it("generates sparkline characters for values", {
    result <- compute_sparkline(c(1, 5, 3, 8, 2))
    expect_length(result, 5)
    expect_true(all(nchar(result) == 1))
  })

  it("handles constant values", {
    result <- compute_sparkline(c(5, 5, 5))
    expect_length(result, 3)
    expect_true(length(unique(result)) == 1)
  })

  it("returns empty for empty input", {
    expect_length(compute_sparkline(numeric(0)), 0)
  })
})

describe("compute_activity_trends", {
  it("computes month-over-month changes", {
    data <- data.frame(
      chapter = c("repo-a", "repo-a", "repo-b", "repo-b"),
      month = c("2024-01", "2024-02", "2024-01", "2024-02"),
      commits = c(10L, 15L, 5L, 8L),
      prs = c(0L, 0L, 0L, 0L),
      issues = c(0L, 0L, 0L, 0L),
      stringsAsFactors = FALSE
    )
    result <- compute_activity_trends(data)
    expect_s3_class(result, "data.frame")
    expect_equal(nrow(result), 2)
    expect_true("total_commits" %in% names(result))
    expect_equal(result$total_commits, c(15L, 23L))
    expect_true(is.na(result$change[1]))
    expect_true(!is.na(result$change[2]))
  })

  it("handles empty data", {
    empty <- data.frame(
      chapter = character(0),
      month = character(0),
      commits = integer(0),
      prs = integer(0),
      issues = integer(0),
      stringsAsFactors = FALSE
    )
    result <- compute_activity_trends(empty)
    expect_equal(nrow(result), 0)
  })
})

describe("compute_growth_rate", {
  it("computes percentage growth", {
    expect_equal(compute_growth_rate(c(100, 150)), 50)
  })

  it("returns NA for single value", {
    expect_true(is.na(compute_growth_rate(c(100))))
  })
})

describe("format_analytics_markdown", {
  it("formats trends and growth into markdown", {
    trends <- data.frame(
      month = c("2024-01", "2024-02"),
      total_commits = c(15L, 23L),
      change = c(NA_real_, 53.3),
      sparkline = c("\u2581", "\u2588"),
      stringsAsFactors = FALSE
    )
    growth <- data.frame(
      month = c("2024-01", "2024-02"),
      new_contributors = c(5L, 3L),
      total_contributors = c(5L, 8L),
      active_repos = c(0L, 0L),
      stringsAsFactors = FALSE
    )
    result <- format_analytics_markdown(trends, growth)
    expect_true(grepl("Analytics Dashboard", result))
    expect_true(grepl("2024-01", result))
    expect_true(grepl("2024-02", result))
  })

  it("handles empty data", {
    empty_t <- data.frame(
      month = character(0),
      total_commits = integer(0),
      change = numeric(0),
      sparkline = character(0),
      stringsAsFactors = FALSE
    )
    empty_g <- data.frame(
      month = character(0),
      new_contributors = integer(0),
      total_contributors = integer(0),
      active_repos = integer(0),
      stringsAsFactors = FALSE
    )
    result <- format_analytics_markdown(empty_t, empty_g)
    expect_true(grepl("No data", result))
  })
})

describe("analytics command parsing", {
  it("parses /jinx analytics", {
    cmd <- parse_command("/jinx analytics")
    expect_equal(cmd$action, "analytics")
  })
})
