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

describe("extract_airtable_photo", {
  it("extracts URL from photo field", {
    photo <- list(list(url = "https://example.com/photo.jpg"))
    expect_identical(
      extract_airtable_photo(photo),
      "https://example.com/photo.jpg"
    )
  })

  it("returns NULL for empty field", {
    expect_null(extract_airtable_photo(NULL))
    expect_null(extract_airtable_photo(list()))
  })

  it("returns NULL when no URL", {
    photo <- list(list(id = "att123"))
    expect_null(extract_airtable_photo(photo))
  })
})
