describe("format_gha_dashboard", {
  it("formats dashboard data as markdown table", {
    data <- list(
      list(
        repository = "jinx",
        workflows = list(
          list(name = "CI", url = "https://github.com/r/j/ci",
               badge = "https://github.com/r/j/ci/badge.svg",
               run = "2024-03-15T10:00:00Z", state = "active"),
          list(name = "Deploy", url = "https://github.com/r/j/deploy",
               badge = "https://github.com/r/j/deploy/badge.svg",
               run = "2024-03-14T08:00:00Z", state = "active")
        )
      ),
      list(
        repository = "website",
        workflows = list(
          list(name = "Build", url = "https://github.com/r/w/build",
               badge = NULL, run = NULL, state = "disabled")
        )
      )
    )
    result <- format_gha_dashboard(data)
    expect_true(grepl("GitHub Actions Status Report", result))
    expect_true(grepl("jinx", result))
    expect_true(grepl("website", result))
    expect_true(grepl("CI", result))
    expect_true(grepl("Deploy", result))
    expect_true(grepl("2024-03-15", result))
    expect_true(grepl("N/A", result))
  })

  it("handles empty data", {
    expect_equal(format_gha_dashboard(list()), "No workflow data found.")
  })

  it("uses state when badge is NULL", {
    data <- list(
      list(
        repository = "test",
        workflows = list(
          list(name = "CI", url = "url", badge = NULL,
               run = "2024-01-01T00:00:00Z", state = "disabled")
        )
      )
    )
    result <- format_gha_dashboard(data)
    expect_true(grepl("disabled", result))
  })
})
