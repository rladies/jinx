describe("tags2hash", {
  it("converts tags to hashtags", {
    expect_equal(tags2hash(c("Data", "Science")), "#Data #Science")
  })

  it("converts standalone R to rstats", {
    expect_equal(tags2hash(c("R", "Python")), "#rstats #Python")
    expect_equal(tags2hash(c("r")), "#rstats")
  })

  it("removes spaces in tags", {
    expect_equal(tags2hash(c("Health data")), "#Healthdata")
  })

  it("removes hyphens in tags", {
    expect_equal(tags2hash(c("open-source")), "#opensource")
  })

  it("handles single tag", {
    expect_equal(tags2hash("DataViz"), "#DataViz")
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
    expect_true(length(unique(emojis)) > 1)
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
    expect_true(grepl("Test Post", msg))
    expect_true(grepl("A great post", msg))
    expect_true(grepl("https://example.com", msg))
    expect_true(grepl("#rstats", msg))
    expect_true(grepl("#Data", msg))
  })
})

describe("parse_command for announce", {
  it("parses announce command", {
    cmd <- parse_command("/jinx announce https://rladies.org/blog/post")
    expect_equal(cmd$action, "announce")
    expect_equal(cmd$url, "https://rladies.org/blog/post")
  })

  it("returns error for missing url", {
    cmd <- parse_command("/jinx announce")
    expect_equal(cmd$action, "error")
  })
})
