describe("load_teams_config", {
  it("loads and parses teams.yml", {
    config <- load_teams_config()
    expect_type(config, "list")
    expect_equal(config$organization, "rladies")
    expect_equal(config$global_team_id, 3388327)
    expect_gte(length(config$teams), 15)
  })

  it("contains all expected teams", {
    config <- load_teams_config()
    expected <- c(
      "abstract-review",
      "blog",
      "campaigns",
      "chapter-activity",
      "chapter-onboarding",
      "coc",
      "communications",
      "community-slack",
      "conference-liaison",
      "directory",
      "meetup-pro",
      "mentoring",
      "rocur",
      "translation",
      "website"
    )
    expect_true(all(expected %in% names(config$teams)))
  })

  it("has required fields for each team", {
    config <- load_teams_config()
    for (slug in names(config$teams)) {
      team <- config$teams[[slug]]
      expect_true("name" %in% names(team), info = slug)
      expect_true("role" %in% names(team), info = slug)
      expect_true("repos" %in% names(team), info = slug)
    }
  })
})

describe("team_by_slug", {
  it("returns team definition for valid slug", {
    team <- team_by_slug("website")
    expect_equal(team$name, "Website")
    expect_equal(team$role, "maintainer")
  })

  it("returns NULL for unknown slug", {
    expect_null(team_by_slug("nonexistent"))
  })
})

describe("team_slugs", {
  it("returns character vector of slugs", {
    slugs <- team_slugs()
    expect_type(slugs, "character")
    expect_true("website" %in% slugs)
    expect_true("blog" %in% slugs)
  })
})
