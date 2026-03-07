describe("validate_blog_entry", {
  it("validates a correct blog entry", {
    tmp <- withr::local_tempdir()
    entry <- list(
      title = "My R-Ladies Talk",
      url = "https://example.com/blog",
      type = "blog",
      authors = list(list(name = "Jane Doe")),
      language = "en"
    )
    path <- file.path(tmp, "entry.json")
    jsonlite::write_json(entry, path, auto_unbox = TRUE)

    result <- validate_blog_entry(path)
    expect_true(result$valid[1])
  })

  it("rejects entry missing required fields", {
    tmp <- withr::local_tempdir()
    entry <- list(title = "Missing fields")
    path <- file.path(tmp, "bad.json")
    jsonlite::write_json(entry, path, auto_unbox = TRUE)

    result <- validate_blog_entry(path)
    expect_false(result$valid[1])
    expect_true(nzchar(result$errors[1]))
  })

  it("validates all json files in a directory", {
    tmp <- withr::local_tempdir()
    good <- list(
      title = "Good",
      url = "https://x.com",
      type = "blog",
      authors = list(list(name = "A")),
      language = "en"
    )
    bad <- list(title = "Bad")
    jsonlite::write_json(good, file.path(tmp, "good.json"), auto_unbox = TRUE)
    jsonlite::write_json(bad, file.path(tmp, "bad.json"), auto_unbox = TRUE)

    result <- validate_blog_entry(tmp)
    expect_equal(nrow(result), 2)
    expect_true(any(result$valid))
    expect_true(any(!result$valid))
  })

  it("handles invalid JSON gracefully", {
    tmp <- withr::local_tempdir()
    path <- file.path(tmp, "broken.json")
    writeLines("not json at all {{{", path)

    result <- validate_blog_entry(path)
    expect_false(result$valid[1])
  })
})
