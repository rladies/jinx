describe("workflow jinx:: references", {
  workflow_dir <- testthat::test_path("..", "..", ".github", "workflows")

  it("only call functions exported from jinx", {
    testthat::skip_if_not(
      dir.exists(workflow_dir),
      "workflows dir unavailable (installed package check)"
    )

    files <- list.files(
      workflow_dir,
      pattern = "\\.ya?ml$",
      full.names = TRUE
    )
    refs <- unique(unlist(lapply(files, function(f) {
      lines <- readLines(f, warn = FALSE)
      matches <- regmatches(
        lines,
        gregexpr("jinx::[a-zA-Z0-9_.]+", lines)
      )
      sub("^jinx::", "", unlist(matches))
    })))

    exports <- getNamespaceExports("jinx")
    missing <- setdiff(refs, exports)
    expect_identical(
      missing,
      character(0),
      info = sprintf(
        "Workflow files call jinx::%s but the package does not export them.",
        paste(missing, collapse = ", jinx::")
      )
    )
  })
})
