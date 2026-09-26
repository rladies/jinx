describe("chapter_team_slug", {
  it("strips the rladies- prefix", {
    expect_identical(chapter_team_slug("rladies-london"), "london")
    expect_identical(
      chapter_team_slug("rladies-san-francisco"),
      "san-francisco"
    )
  })

  it("keeps the urlname's disambiguation between same-named cities", {
    expect_identical(chapter_team_slug("rladies-ldnont"), "ldnont")
    expect_identical(chapter_team_slug("rladies-athens-ga"), "athens-ga")
    expect_identical(chapter_team_slug("rladies-athens-gr"), "athens-gr")
  })

  it("accepts a urlname that has no prefix", {
    expect_identical(chapter_team_slug("pdx"), "pdx")
  })

  it("honours an override for an unusable urlname", {
    long <- "Spotkania-Entuzjastow-R-Warsaw-R-Users-Group-Meetup"
    expect_identical(
      chapter_team_slug(
        long,
        overrides = c(
          `Spotkania-Entuzjastow-R-Warsaw-R-Users-Group-Meetup` = "warsaw"
        )
      ),
      "warsaw"
    )
  })

  it("normalises an awkward urlname when there is no override", {
    expect_identical(chapter_team_slug("RLadies-Sao_Paulo"), "sao-paulo")
  })

  it("is NA when the chapter has no Meetup group", {
    expect_true(is.na(chapter_team_slug(NULL)))
    expect_true(is.na(chapter_team_slug("")))
  })
})

describe("chapter_team_name", {
  it("title-cases the slug so it round-trips back to it", {
    for (slug in c("london", "san-francisco", "athens-ga", "portland-maine")) {
      expect_identical(chapter_slug(chapter_team_name(slug)), slug)
    }
  })

  it("keeps known acronyms upper case, as the org already writes them", {
    expect_identical(chapter_team_name("pdx"), "PDX")
    expect_identical(chapter_team_name("rtp"), "RTP")
    expect_identical(chapter_team_name("dc"), "DC")
  })

  it("refuses to build a name with no slug", {
    expect_error(chapter_team_name(""), "without a slug")
    expect_error(chapter_team_name(NA_character_), "without a slug")
  })
})

describe("chapter_team_description", {
  it("spells the chapter out, which the name cannot", {
    expect_identical(
      chapter_team_description("Portland", "USA", "Oregon"),
      "RLadies+ chapter in Portland, Oregon, USA"
    )
  })

  it("omits a region that is not given", {
    expect_identical(
      chapter_team_description("Oslo", "Norway"),
      "RLadies+ chapter in Oslo, Norway"
    )
  })

  it("refuses without a city", {
    expect_error(chapter_team_description("", "Norway"), "without a city")
  })
})

describe("chapter_team_name_check", {
  it("passes when the name produces the wanted slug", {
    expect_true(chapter_team_name_check("San Francisco", "san-francisco"))
  })

  it("refuses a name GitHub would slug differently", {
    expect_error(
      chapter_team_name_check("Portland, Oregon, USA", "pdx"),
      "would derive"
    )
  })
})

describe("chapter_team_audit", {
  chapters <- list(
    list(
      file = "a.json",
      city = "London",
      country = "United Kingdom",
      status = "active",
      urlname = "rladies-london"
    ),
    list(
      file = "b.json",
      city = "Portland",
      country = "USA",
      status = "active",
      urlname = "rladies-pdx"
    ),
    list(
      file = "c.json",
      city = "Bergen",
      country = "Norway",
      status = "active",
      urlname = "rladies-bergen"
    )
  )

  mock_sources <- function(teams) {
    local_mocked_bindings(
      chapter_teams_fetch = function(...) teams,
      chapter_index_fetch = function(...) paste0(letters[1:3], ".json"),
      chapter_entry_fetch = function(file, ...) {
        chapters[[match(file, paste0(letters[1:3], ".json"))]]
      },
      .env = parent.frame()
    )
  }

  it("calls a team matching a chapter's urlname ok", {
    mock_sources(data.frame(slug = "london", display = "London"))
    audit <- chapter_team_audit()
    expect_identical(audit$finding[which(audit$team == "london")], "ok")
  })

  it("flags a team named for the city when the urlname differs", {
    mock_sources(data.frame(slug = "portland", display = "Portland"))
    audit <- chapter_team_audit()
    row <- audit[which(audit$team == "portland"), ]
    expect_identical(row$finding, "slug_mismatch")
    expect_identical(row$expected_slug, "pdx")
  })

  it("flags a team no chapter explains", {
    mock_sources(data.frame(slug = "jozi", display = "Jozi"))
    audit <- chapter_team_audit()
    expect_identical(audit$finding[which(audit$team == "jozi")], "no_chapter")
  })

  it("flags active chapters that have no team", {
    mock_sources(data.frame(slug = "london", display = "London"))
    audit <- chapter_team_audit()
    missing <- audit[audit$finding == "missing_team", ]
    expect_setequal(missing$expected_slug, c("pdx", "bergen"))
  })

  it("does not ask for teams for chapters of other statuses", {
    chapters[[3]]$status <<- "retired on 01-01-2020"
    mock_sources(data.frame(slug = "london", display = "London"))
    audit <- chapter_team_audit()
    expect_false("bergen" %in% audit$expected_slug)
    chapters[[3]]$status <<- "active"
  })
})

describe("chapter_team_audit_report", {
  audit <- data.frame(
    finding = c("ok", "slug_mismatch", "no_chapter", "missing_team"),
    team = c("london", "portland", "jozi", NA),
    display = c("London", "Portland", "Jozi", NA),
    chapter = c(
      "London, United Kingdom",
      "Portland, USA",
      NA,
      "Bergen, Norway"
    ),
    expected_slug = c("london", "pdx", NA, "bergen"),
    stringsAsFactors = FALSE
  )

  it("counts each finding", {
    body <- chapter_team_audit_report(audit)
    expect_match(
      body,
      "1 team matches a chapter's Meetup urlname",
      fixed = TRUE
    )
  })

  it("says why it is not fixing them itself", {
    expect_match(chapter_team_audit_report(audit), "reported rather than fixed")
  })

  it("names the slug a mismatched team would have", {
    expect_match(chapter_team_audit_report(audit), "uses `pdx`", fixed = TRUE)
  })

  it("lists chapters that need a team", {
    expect_match(
      chapter_team_audit_report(audit),
      "would be `bergen`",
      fixed = TRUE
    )
  })

  it("omits sections with nothing in them", {
    clean <- audit[audit$finding == "ok", ]
    body <- chapter_team_audit_report(clean)
    expect_false(grepl("### ", body))
  })
})

describe("chapter_team_create", {
  it("refuses a chapter with no urlname, since the slug would not be unique", {
    expect_error(
      chapter_team_create(NULL, "Sheffield", "United Kingdom"),
      "without a Meetup urlname"
    )
  })

  it("does nothing when the team already exists", {
    created <- FALSE
    local_mocked_bindings(
      chapter_teams_fetch = function(...) {
        data.frame(slug = "london", display = "London")
      }
    )
    local_mocked_bindings(
      gh = function(...) {
        created <<- TRUE
        list()
      },
      .package = "gh"
    )
    expect_message(
      slug <- chapter_team_create("rladies-london", "London", "United Kingdom")
    )
    expect_identical(slug, "london")
    expect_false(created)
  })

  it("creates the team under the parent with a spelled-out description", {
    sent <- NULL
    local_mocked_bindings(
      chapter_teams_fetch = function(...) {
        data.frame(slug = character(0), display = character(0))
      },
      chapter_parent_team_id = function(...) 7042367
    )
    local_mocked_bindings(
      gh = function(endpoint, ...) {
        sent <<- list(...)
        list(slug = "pdx")
      },
      .package = "gh"
    )
    expect_message(chapter_team_create(
      "rladies-pdx",
      "Portland",
      "USA",
      "Oregon"
    ))
    expect_identical(sent$name, "PDX")
    expect_identical(
      sent$description,
      "RLadies+ chapter in Portland, Oregon, USA"
    )
    expect_identical(sent$parent_team_id, 7042367)
    expect_identical(sent$privacy, "closed")
  })

  it("warns if GitHub derives a different slug than intended", {
    local_mocked_bindings(
      chapter_teams_fetch = function(...) {
        data.frame(slug = character(0), display = character(0))
      },
      chapter_parent_team_id = function(...) 1
    )
    local_mocked_bindings(
      gh = function(...) list(slug = "something-else"),
      .package = "gh"
    )
    expect_message(chapter_team_create("rladies-pdx", "Portland", "USA"), "not")
  })
})

describe("/jinx chapter-team-audit", {
  it("parses with no arguments", {
    expect_identical(
      cmd_parse("/jinx chapter-team-audit")$action,
      "chapter-team-audit"
    )
  })

  it("accepts the spelled-out phrasings", {
    expect_identical(
      cmd_parse("/jinx chapter team audit")$action,
      "chapter-team-audit"
    )
    expect_identical(
      cmd_parse("/jinx audit chapter teams")$action,
      "chapter-team-audit"
    )
  })

  it("is safe, since it only reads", {
    expect_identical(
      jinx_commands()[["chapter-team-audit"]]$keyword,
      "jinx_safe"
    )
  })
})
