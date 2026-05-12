describe("format_report_markdown", {
  it("formats a report with active repos", {
    report <- list(
      type = "Weekly",
      period = list(from = "2024-03-01", to = "2024-03-07"),
      generated_at = as.POSIXct("2024-03-07 12:00:00", tz = "UTC"),
      summary = list(
        active_repos = 3L,
        total_commits = 15L,
        total_prs = 5L,
        total_prs_merged = 3L,
        total_issues = 8L,
        total_issues_closed = 4L
      ),
      repos = list(
        list(
          repo = "jinx",
          commits = 10L,
          prs_opened = 3L,
          prs_merged = 2L,
          issues_opened = 5L,
          issues_closed = 3L
        ),
        list(
          repo = "website",
          commits = 5L,
          prs_opened = 2L,
          prs_merged = 1L,
          issues_opened = 3L,
          issues_closed = 1L
        )
      )
    )
    result <- format_report_markdown(report)
    expect_true(grepl("Weekly Activity Report", result, fixed = TRUE))
    expect_true(grepl("2024-03-01", result, fixed = TRUE))
    expect_true(grepl("Active repositories | 3", result, fixed = TRUE))
    expect_true(grepl("jinx", result, fixed = TRUE))
    expect_true(grepl("website", result, fixed = TRUE))
  })

  it("handles empty repo activity", {
    report <- list(
      type = "Weekly",
      period = list(from = "2024-03-01", to = "2024-03-07"),
      generated_at = as.POSIXct("2024-03-07 12:00:00", tz = "UTC"),
      summary = list(
        active_repos = 0L,
        total_commits = 0L,
        total_prs = 0L,
        total_prs_merged = 0L,
        total_issues = 0L,
        total_issues_closed = 0L
      ),
      repos = list(
        list(
          repo = "jinx",
          commits = 0L,
          prs_opened = 0L,
          prs_merged = 0L,
          issues_opened = 0L,
          issues_closed = 0L
        )
      )
    )
    result <- format_report_markdown(report)
    expect_true(grepl("No activity", result, fixed = TRUE))
  })

  it("sorts repos by commit count", {
    report <- list(
      type = "Weekly",
      period = list(from = "2024-03-01", to = "2024-03-07"),
      generated_at = as.POSIXct("2024-03-07 12:00:00", tz = "UTC"),
      summary = list(
        active_repos = 2L,
        total_commits = 15L,
        total_prs = 0L,
        total_prs_merged = 0L,
        total_issues = 0L,
        total_issues_closed = 0L
      ),
      repos = list(
        list(
          repo = "small",
          commits = 2L,
          prs_opened = 0L,
          prs_merged = 0L,
          issues_opened = 0L,
          issues_closed = 0L
        ),
        list(
          repo = "big",
          commits = 13L,
          prs_opened = 0L,
          prs_merged = 0L,
          issues_opened = 0L,
          issues_closed = 0L
        )
      )
    )
    result <- format_report_markdown(report)
    big_pos <- regexpr("big", result, fixed = TRUE)
    small_pos <- regexpr("small", result, fixed = TRUE)
    expect_lt(big_pos, small_pos)
  })
})

describe("format_chapter_report", {
  it("formats chapter health data", {
    health <- data.frame(
      chapter = c("Buenos Aires", "London", "Berlin"),
      status = c("active", "inactive", "active"),
      last_event = c("2024-02-01", "2023-06-01", "2024-03-01"),
      months_inactive = c(1L, 9L, 0L),
      stringsAsFactors = FALSE
    )
    result <- format_chapter_report(health, months = 6)
    expect_true(grepl("Chapter Health Report", result, fixed = TRUE))
    expect_true(grepl("Active chapters.*2", result))
    expect_true(grepl("Inactive chapters.*1", result))
    expect_true(grepl("London", result, fixed = TRUE))
    expect_false(grepl("Buenos Aires.*\\|", result))
  })

  it("shows all active message when none inactive", {
    health <- data.frame(
      chapter = c("Buenos Aires", "Berlin"),
      status = c("active", "active"),
      last_event = c("2024-02-01", "2024-03-01"),
      months_inactive = c(1L, 0L),
      stringsAsFactors = FALSE
    )
    result <- format_chapter_report(health, months = 6)
    expect_true(grepl("All chapters are active", result, fixed = TRUE))
  })

  it("sorts inactive chapters by months inactive", {
    health <- data.frame(
      chapter = c("Alpha", "Bravo", "Charlie"),
      status = c("inactive", "inactive", "inactive"),
      last_event = c("2023-09-01", "2023-01-01", "2023-06-01"),
      months_inactive = c(6L, 14L, 9L),
      stringsAsFactors = FALSE
    )
    result <- format_chapter_report(health, months = 6)
    bravo_pos <- regexpr("Bravo", result, fixed = TRUE)
    charlie_pos <- regexpr("Charlie", result, fixed = TRUE)
    alpha_pos <- regexpr("Alpha", result, fixed = TRUE)
    expect_lt(bravo_pos, charlie_pos)
    expect_lt(charlie_pos, alpha_pos)
  })
})
