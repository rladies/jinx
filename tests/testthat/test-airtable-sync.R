describe("airtable_to_directory_entry", {
  it("converts a record with name", {
    record <- list(
      id = "rec123",
      fields = list(
        Name = "Jane Doe",
        github = "janedoe",
        twitter = "jane_doe"
      )
    )
    result <- airtable_to_directory_entry(record)
    expect_identical(result$slug, "jane-doe")
    expect_identical(result$data$name, "Jane Doe")
    expect_identical(result$data$github, "janedoe")
    expect_identical(result$data$twitter, "jane_doe")
    expect_identical(result$airtable_id, "rec123")
  })

  it("returns NULL for record without name", {
    record <- list(id = "rec123", fields = list(github = "someone"))
    expect_null(airtable_to_directory_entry(record))
  })

  it("returns NULL for empty name", {
    record <- list(id = "rec123", fields = list(Name = ""))
    expect_null(airtable_to_directory_entry(record))
  })

  it("generates slug from name", {
    record <- list(
      id = "rec456",
      fields = list(Name = "Maria del Carmen")
    )
    result <- airtable_to_directory_entry(record)
    expect_identical(result$slug, "maria-del-carmen")
  })

  it("omits empty social fields", {
    record <- list(
      id = "rec789",
      fields = list(Name = "Test User", github = "", twitter = "testuser")
    )
    result <- airtable_to_directory_entry(record)
    expect_null(result$data$github)
    expect_identical(result$data$twitter, "testuser")
  })

  it("handles all social media fields", {
    record <- list(
      id = "rec000",
      fields = list(
        Name = "Full User",
        twitter = "tw",
        github = "gh",
        linkedin = "li",
        mastodon = "ma",
        bluesky = "bs",
        website = "ws",
        orcid = "or"
      )
    )
    result <- airtable_to_directory_entry(record)
    expect_identical(result$data$twitter, "tw")
    expect_identical(result$data$github, "gh")
    expect_identical(result$data$linkedin, "li")
    expect_identical(result$data$mastodon, "ma")
    expect_identical(result$data$bluesky, "bs")
    expect_identical(result$data$website, "ws")
    expect_identical(result$data$orcid, "or")
  })
})

describe("airtable_extract_photo", {
  it("extracts URL from photo field", {
    photo <- list(list(url = "https://example.com/photo.jpg"))
    expect_identical(
      airtable_extract_photo(photo),
      "https://example.com/photo.jpg"
    )
  })

  it("returns NULL for empty field", {
    expect_null(airtable_extract_photo(NULL))
    expect_null(airtable_extract_photo(list()))
  })

  it("returns NULL when no URL", {
    photo <- list(list(id = "att123"))
    expect_null(airtable_extract_photo(photo))
  })
})

describe("write_directory_entries", {
  it("returns changed entries with content, path, and sha", {
    entries <- list(
      list(
        slug = "jane-doe",
        data = list(name = "Jane Doe"),
        airtable_id = "r1"
      )
    )
    local_mocked_bindings(
      gh = function(endpoint, ...) {
        list(
          content = jsonlite::base64_enc(charToRaw("old json")),
          sha = "abc123"
        )
      },
      .package = "gh"
    )
    result <- write_directory_entries(entries, "rladies", "directory")
    expect_length(result, 1)
    expect_identical(result[[1]]$filename, "jane-doe.json")
    expect_identical(result[[1]]$path, "contact/jane-doe.json")
    expect_identical(result[[1]]$sha, "abc123")
    expect_true(grepl("Jane Doe", result[[1]]$content, fixed = TRUE))
  })

  it("skips entries whose content already matches", {
    matching <- jsonlite::toJSON(
      list(name = "Jane Doe"),
      pretty = TRUE,
      auto_unbox = TRUE
    )
    entries <- list(
      list(
        slug = "jane-doe",
        data = list(name = "Jane Doe"),
        airtable_id = "r1"
      )
    )
    local_mocked_bindings(
      gh = function(endpoint, ...) {
        list(
          content = jsonlite::base64_enc(charToRaw(as.character(matching))),
          sha = "abc123"
        )
      },
      .package = "gh"
    )
    result <- write_directory_entries(entries, "rladies", "directory")
    expect_length(result, 0)
  })
})

describe("directory_create_pr", {
  it("returns NULL when no changes", {
    expect_null(directory_create_pr(list(), "rladies", "directory"))
  })

  it("creates branch, commits files, and opens a PR", {
    calls <- list()
    local_mocked_bindings(
      gh = function(endpoint, ...) {
        calls[[length(calls) + 1]] <<- endpoint
        if (grepl("git/ref/heads", endpoint)) {
          return(list(object = list(sha = "basesha")))
        }
        if (grepl("/contents/", endpoint) && grepl("^GET", endpoint)) {
          stop("not found")
        }
        if (grepl("^GET /repos.*/pulls", endpoint)) {
          return(list())
        }
        if (grepl("^POST /repos.*/pulls", endpoint)) {
          return(list(html_url = "https://github.com/x/y/pull/42"))
        }
        list()
      },
      .package = "gh"
    )
    changed <- list(
      list(
        filename = "a.json",
        path = "contact/a.json",
        content = "{}",
        sha = NULL
      )
    )
    url <- directory_create_pr(changed, "rladies", "directory")
    expect_identical(url, "https://github.com/x/y/pull/42")
    expect_true(any(grepl("POST /repos.*/git/refs", calls)))
    expect_true(any(grepl("PUT /repos.*/contents/", calls)))
    expect_true(any(grepl("POST /repos.*/pulls", calls)))
  })
})
