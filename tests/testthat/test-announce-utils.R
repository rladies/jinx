describe("tags2hash", {
  it("converts tags to hashtags", {
    expect_identical(tags2hash(c("Data", "Science")), "#Data #Science")
  })

  it("converts standalone R to rstats", {
    expect_identical(tags2hash(c("R", "Python")), "#rstats #Python")
    expect_identical(tags2hash("r"), "#rstats")
  })

  it("removes spaces in tags", {
    expect_identical(tags2hash("Health data"), "#Healthdata")
  })

  it("removes hyphens in tags", {
    expect_identical(tags2hash("open-source"), "#opensource")
  })

  it("handles single tag", {
    expect_identical(tags2hash("DataViz"), "#DataViz")
  })
})

describe("random_emoji", {
  it("returns a single character", {
    emoji <- random_emoji()
    expect_type(emoji, "character")
    expect_length(emoji, 1)
  })

  it("returns different values (probabilistic)", {
    emojis <- vapply(seq_len(20), function(i) random_emoji(), character(1))
    expect_gt(length(unique(emojis)), 1)
  })
})

describe("create_announcement_message", {
  it("includes title, description, url, and tags", {
    fm <- list(
      title = "Test Post",
      description = "A great post",
      tags = c("R", "Data")
    )
    msg <- create_announcement_message(fm, "https://example.com")
    expect_true(grepl("Test Post", msg, fixed = TRUE))
    expect_true(grepl("A great post", msg, fixed = TRUE))
    expect_true(grepl("https://example.com", msg))
    expect_true(grepl("#rstats", msg, fixed = TRUE))
    expect_true(grepl("#Data", msg, fixed = TRUE))
  })
})

describe("command_parse for announce", {
  it("parses announce command", {
    cmd <- command_parse("/jinx announce https://rladies.org/blog/post")
    expect_identical(cmd$action, "announce")
    expect_identical(cmd$url, "https://rladies.org/blog/post")
  })

  it("returns error for missing url", {
    cmd <- command_parse("/jinx announce")
    expect_identical(cmd$action, "error")
  })
})
