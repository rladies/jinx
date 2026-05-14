describe("contributor_format_table", {
  it("formats as markdown table", {
    df <- data.frame(
      login = c("alice", "bob"),
      contributions = c(10L, 5L),
      avatar_url = c("https://example.com/a.png", "https://example.com/b.png"),
      profile_url = c("https://github.com/alice", "https://github.com/bob"),
      stringsAsFactors = FALSE
    )
    result <- contributor_format_table(df)
    expect_true(grepl("| Avatar | Contributor", result, fixed = TRUE))
    expect_true(grepl("@alice", result, fixed = TRUE))
    expect_true(grepl("@bob", result, fixed = TRUE))
    expect_true(grepl("10", result, fixed = TRUE))
  })
})

describe("contributor_format_grid", {
  it("formats as image grid", {
    df <- data.frame(
      login = c("alice", "bob"),
      contributions = c(10L, 5L),
      avatar_url = c("https://example.com/a.png", "https://example.com/b.png"),
      profile_url = c("https://github.com/alice", "https://github.com/bob"),
      stringsAsFactors = FALSE
    )
    result <- contributor_format_grid(df, cols = 7)
    expect_true(grepl("alice", result, fixed = TRUE))
    expect_true(grepl("bob", result, fixed = TRUE))
    expect_true(grepl("<img", result, fixed = TRUE))
  })

  it("wraps rows at specified columns", {
    df <- data.frame(
      login = paste0("user", 1:5),
      contributions = rep(1L, 5),
      avatar_url = rep("https://example.com/a.png", 5),
      profile_url = rep("https://github.com/user", 5),
      stringsAsFactors = FALSE
    )
    result <- contributor_format_grid(df, cols = 3)
    lines <- strsplit(result, "\n\n")[[1]]
    expect_length(lines, 2)
  })
})

describe("contributor_format", {
  it("returns empty message for empty data", {
    df <- data.frame(
      login = character(0),
      contributions = integer(0),
      avatar_url = character(0),
      profile_url = character(0),
      stringsAsFactors = FALSE
    )
    expect_identical(contributor_format(df), "No contributors yet.")
  })

  it("dispatches to table format", {
    df <- data.frame(
      login = "alice",
      contributions = 1L,
      avatar_url = "url",
      profile_url = "url",
      stringsAsFactors = FALSE
    )
    result <- contributor_format(df, format = "table")
    expect_true(grepl("Avatar", result, fixed = TRUE))
  })

  it("dispatches to grid format", {
    df <- data.frame(
      login = "alice",
      contributions = 1L,
      avatar_url = "url",
      profile_url = "url",
      stringsAsFactors = FALSE
    )
    result <- contributor_format(df, format = "grid")
    expect_true(grepl("<img", result, fixed = TRUE))
  })
})
