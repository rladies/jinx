describe("format_goodpractice_report", {
  it("reports all-pass when there are no failures", {
    local_mocked_bindings(
      failing_check_names = function(gp_result) character(0)
    )
    result <- format_goodpractice_report(list())
    expect_match(result, "All checks passed", fixed = TRUE)
  })

  it("lists each failing check with its description", {
    local_mocked_bindings(
      failing_check_names = function(gp_result) {
        c("lintr_line_length_linter", "no_description_depends")
      }
    )
    local_mocked_bindings(
      failed_positions = function(gp_result) list(),
      .package = "goodpractice"
    )
    local_mocked_bindings(
      describe_check = function(name) {
        list("Code lines are short")
      },
      .package = "goodpractice"
    )

    result <- format_goodpractice_report(list())
    expect_match(result, "Found 2 failing check", fixed = TRUE)
    expect_match(result, "lintr_line_length_linter", fixed = TRUE)
    expect_match(result, "no_description_depends", fixed = TRUE)
    expect_match(result, "Code lines are short", fixed = TRUE)
  })

  it("shows up to max_positions source locations per check", {
    local_mocked_bindings(
      failing_check_names = function(gp_result) "lintr_line_length_linter"
    )
    local_mocked_bindings(
      failed_positions = function(gp_result) {
        list(
          lintr_line_length_linter = lapply(1:8, function(i) {
            list(filename = "R/foo.R", line_number = i * 10L)
          })
        )
      },
      .package = "goodpractice"
    )
    local_mocked_bindings(
      describe_check = function(name) list("Code lines are short"),
      .package = "goodpractice"
    )

    result <- format_goodpractice_report(list(), max_positions = 3L)
    expect_match(result, "R/foo.R:10", fixed = TRUE)
    expect_match(result, "R/foo.R:20", fixed = TRUE)
    expect_match(result, "R/foo.R:30", fixed = TRUE)
    expect_false(grepl("R/foo.R:40", result, fixed = TRUE))
    expect_match(result, "5 more", fixed = TRUE)
  })

  it("truncates output exceeding max_chars", {
    local_mocked_bindings(
      failing_check_names = function(gp_result) "lintr_line_length_linter"
    )
    local_mocked_bindings(
      failed_positions = function(gp_result) {
        list(
          lintr_line_length_linter = lapply(1:200, function(i) {
            list(filename = paste0("R/file", i, ".R"), line_number = i)
          })
        )
      },
      .package = "goodpractice"
    )
    local_mocked_bindings(
      describe_check = function(name) list("Code lines are short"),
      .package = "goodpractice"
    )

    result <- format_goodpractice_report(
      list(),
      max_positions = 200L,
      max_chars = 200L
    )
    expect_lte(nchar(result), 300L)
    expect_match(result, "truncated", fixed = TRUE)
  })

  it("strips ANSI escape sequences", {
    local_mocked_bindings(
      failing_check_names = function(gp_result) "\033[31mbad_check\033[0m"
    )
    local_mocked_bindings(
      failed_positions = function(gp_result) list(),
      .package = "goodpractice"
    )
    local_mocked_bindings(
      describe_check = function(name) list("\033[1mDescription\033[0m"),
      .package = "goodpractice"
    )

    result <- format_goodpractice_report(list())
    expect_false(grepl("\033", result, fixed = TRUE))
    expect_match(result, "bad_check", fixed = TRUE)
    expect_match(result, "Description", fixed = TRUE)
  })
})

describe("failing_check_names", {
  it("falls back to walking $checks when failed_checks errors", {
    local_mocked_bindings(
      failed_checks = function(gp_result) stop("not available"),
      .package = "goodpractice"
    )
    gp_result <- list(
      checks = list(
        a = list(status = TRUE),
        b = list(status = FALSE),
        c = TRUE,
        d = FALSE
      )
    )
    expect_identical(failing_check_names(gp_result), c("b", "d"))
  })
})
