describe("directory_collision_issue", {
  it("flags a numeric-suffixed slug", {
    expect_length(directory_collision_issue("jane-doe.json"), 0)
    expect_match(directory_collision_issue("jane-doe-1.json"), "numeric suffix")
  })
})

describe("directory_filename_issues", {
  it("reports invalid filenames", {
    expect_length(directory_filename_issues("jane-doe.json"), 0)
    expect_match(directory_filename_issues("Jane.json"), "filename:")
  })
})

describe("directory_contact_social_issues", {
  it("flags a contact method with no matching social entry", {
    entry <- list(
      contact_method = list("Twitter"),
      social_media = list(twitter = "janedoe")
    )
    expect_length(directory_contact_social_issues(entry), 0)

    missing <- list(contact_method = list("Twitter"), social_media = list())
    expect_match(
      directory_contact_social_issues(missing),
      "social_media.twitter is empty"
    )
  })

  it("ignores email as a contact method", {
    entry <- list(contact_method = list("Email"), social_media = list())
    expect_length(directory_contact_social_issues(entry), 0)
  })
})

describe("directory_sensitive_issues", {
  it("flags a stray email in free text", {
    hit <- list(bio = "reach me at jane@example.com anytime")
    expect_match(directory_sensitive_issues(hit), "possible email address")

    clean <- list(bio = "R enthusiast", work = list(title = "Analyst"))
    expect_length(directory_sensitive_issues(clean), 0)
  })
})

describe("directory_review_entry", {
  it("returns no issues for a clean entry", {
    entry <- list(
      name = "Jane Doe",
      contact_method = list("Twitter"),
      social_media = list(twitter = "janedoe"),
      bio = "R enthusiast"
    )
    result <- directory_review_entry(
      entry,
      "jane-doe.json",
      verify_handles = FALSE
    )
    expect_identical(result$file, "jane-doe.json")
    expect_length(result$issues, 0)
  })

  it("reports unreadable content", {
    result <- directory_review_entry(
      NULL,
      "jane-doe.json",
      verify_handles = FALSE
    )
    expect_match(result$issues, "could not read entry content")
  })
})

describe("directory_review_format", {
  it("reports an all-clear", {
    body <- directory_review_format(list(
      list(file = "a.json", issues = character(0))
    ))
    expect_match(body, "All automated checks passed", fixed = TRUE)
    expect_match(body, "- **a.json** - OK", fixed = TRUE)
  })

  it("lists issues with a count and pluralisation", {
    body <- directory_review_format(list(
      list(file = "a.json", issues = c("issue one", "issue two")),
      list(file = "b.json", issues = character(0))
    ))
    expect_match(body, "2 items to review", fixed = TRUE)
    expect_match(body, "  - issue one", fixed = TRUE)
    expect_match(body, "- **b.json** - OK", fixed = TRUE)
  })
})
