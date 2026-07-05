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
    result <- directory_review_entry(entry, "jane-doe.json")
    expect_identical(result$file, "jane-doe.json")
    expect_length(result$issues, 0)
    expect_match(result$links, "[twitter](https://x.com/janedoe)", fixed = TRUE)
  })

  it("reports unreadable content", {
    result <- directory_review_entry(NULL, "jane-doe.json")
    expect_match(result$issues, "could not read entry content")
    expect_length(result$links, 0)
  })
})

describe("directory_profile_links", {
  it("builds clickable links for each known platform", {
    entry <- list(
      social_media = list(
        twitter = "janedoe",
        github = "jane",
        linkedin = "jane-doe",
        mastodon = "@jane@fosstodon.org",
        website = "example.com"
      )
    )
    links <- directory_profile_links(entry)
    expect_match(links, "Profiles (click to check):", fixed = TRUE)
    expect_match(links, "[twitter](https://x.com/janedoe)", fixed = TRUE)
    expect_match(links, "[github](https://github.com/jane)", fixed = TRUE)
    expect_match(
      links,
      "[linkedin](https://www.linkedin.com/in/jane-doe)",
      fixed = TRUE
    )
    expect_match(
      links,
      "[mastodon](https://fosstodon.org/@jane)",
      fixed = TRUE
    )
    expect_match(links, "[website](https://example.com)", fixed = TRUE)
  })

  it("returns nothing when there is no social media", {
    expect_length(directory_profile_links(list()), 0)
    expect_length(directory_profile_links(list(social_media = list())), 0)
  })
})

describe("directory_review_format", {
  it("renders each entry as a task-list checkbox", {
    body <- directory_review_format(list(
      list(file = "a.json", issues = character(0))
    ))
    expect_match(body, "Tick each entry as you review it", fixed = TRUE)
    expect_match(body, "- [ ] **a.json**", fixed = TRUE)
    expect_match(body, "Before merging, confirm manually", fixed = TRUE)
    expect_match(
      body,
      "- [ ] Each person is a minority-gender person",
      fixed = TRUE
    )
  })

  it("shows flags under a checkbox and counts them", {
    body <- directory_review_format(list(
      list(file = "a.json", issues = c("issue one", "issue two")),
      list(file = "b.json", issues = character(0))
    ))
    expect_match(body, "2 automated flags below", fixed = TRUE)
    expect_match(body, "- [ ] **a.json**", fixed = TRUE)
    expect_match(body, "  - issue one", fixed = TRUE)
    expect_match(body, "- [ ] **b.json**", fixed = TRUE)
  })
})
