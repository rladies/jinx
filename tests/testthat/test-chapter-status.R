checklist_body <- paste(
  "We have received a request to activate a new chapter in **Oslo**.",
  "",
  "### Initial checks",
  "",
  "The @rladies/chapter-onboarding team will:",
  "",
  "-  [x] search the database on GitHub",
  "-  [ ] make sure it is a city using Google Maps",
  "",
  "#### Email",
  "",
  "The @rladies/email team will:",
  "",
  "-  [ ] create the chapter email",
  "-  [ ] post the email address in this issue",
  sep = "\n"
)

describe("chapter_checklist_parse", {
  it("returns one row per task item", {
    state <- chapter_checklist_parse(checklist_body)
    expect_identical(nrow(state), 4L)
    expect_identical(state$done, c(TRUE, FALSE, FALSE, FALSE))
  })

  it("carries the section each item sits under", {
    state <- chapter_checklist_parse(checklist_body)
    expect_identical(unique(state$section), c("Initial checks", "Email"))
  })

  it("attributes items to the team named above them", {
    state <- chapter_checklist_parse(checklist_body)
    expect_identical(state$owner[1], "rladies/chapter-onboarding")
    expect_identical(state$owner[4], "rladies/email")
  })

  it("ignores prose, headings, and plain bullets", {
    state <- chapter_checklist_parse("## Heading\n\n- a plain bullet\n\ntext")
    expect_identical(nrow(state), 0L)
  })

  it("survives an empty or missing body", {
    expect_identical(nrow(chapter_checklist_parse("")), 0L)
    expect_identical(nrow(chapter_checklist_parse(NULL)), 0L)
  })

  it("accepts an upper-case tick", {
    state <- chapter_checklist_parse("- [X] done thing")
    expect_true(state$done)
  })
})

describe("chapter_onboard_blocker", {
  it("names the owner of the first unchecked item", {
    state <- chapter_checklist_parse(checklist_body)
    expect_identical(
      chapter_onboard_blocker(state),
      "rladies/chapter-onboarding"
    )
  })

  it("is NA when everything is done", {
    state <- chapter_checklist_parse("- [x] all done")
    expect_true(is.na(chapter_onboard_blocker(state)))
  })
})

describe("chapter_onboard_summary", {
  it("counts progress and names the next step and its owner", {
    body <- chapter_onboard_summary(chapter_checklist_parse(checklist_body))
    expect_match(body, "1 of 4 steps complete")
    expect_match(body, "Next: make sure it is a city")
    expect_match(body, "@rladies/chapter-onboarding", fixed = TRUE)
  })

  it("ticks a section only when all of its items are done", {
    body <- chapter_onboard_summary(chapter_checklist_parse(checklist_body))
    expect_match(body, "- [ ] **Initial checks** - 1/2", fixed = TRUE)
    expect_match(body, "- [ ] **Email** - 0/2", fixed = TRUE)
  })

  it("says so when the checklist is complete", {
    body <- chapter_onboard_summary(chapter_checklist_parse("- [x] only step"))
    expect_match(body, "Everything is ticked off")
  })

  it("says so when there is no checklist at all", {
    body <- chapter_onboard_summary(chapter_checklist_parse(""))
    expect_match(body, "No checklist found")
  })
})

describe("chapter_status_report", {
  it("reports when no open issue matches the city", {
    local_mocked_bindings(chapter_find_issue = function(...) NULL)
    expect_match(
      chapter_status_report("Atlantis"),
      "No open onboarding issue found"
    )
  })

  it("renders the checklist for an issue number", {
    local_mocked_bindings(
      chapter_onboard_state = function(...) {
        chapter_checklist_parse(checklist_body)
      }
    )
    body <- chapter_status_report(12)
    expect_match(body, "new-chapters-onboarding#12")
    expect_match(body, "1 of 4 steps complete")
  })
})

describe("chapter_find_issue", {
  issues <- list(
    list(number = 3, title = "Bergen, Norway chapter setup"),
    list(number = 4, title = "Oslo, Norway chapter setup")
  )

  it("matches the city part of the title", {
    local_mocked_bindings(gh = function(...) issues, .package = "gh")
    expect_identical(chapter_find_issue("oslo"), 4)
  })

  it("matches regardless of accents and case", {
    local_mocked_bindings(
      gh = function(...) {
        list(list(number = 9, title = "Córdoba, Argentina chapter setup"))
      },
      .package = "gh"
    )
    expect_identical(chapter_find_issue("Cordoba"), 9)
  })

  it("returns NULL when nothing matches", {
    local_mocked_bindings(gh = function(...) issues, .package = "gh")
    expect_null(chapter_find_issue("Atlantis"))
  })
})

describe("/jinx chapter-status parsing", {
  it("takes a city", {
    expect_identical(
      cmd_parse("/jinx chapter-status Oslo"),
      list(action = "chapter-status", ref = "Oslo")
    )
  })

  it("takes an issue number", {
    expect_identical(cmd_parse("/jinx chapter-status 12")$ref, "12")
  })

  it("accepts the spelled-out phrasing", {
    expect_identical(cmd_parse("/jinx chapter status Oslo")$ref, "Oslo")
  })

  it("keeps a multi-word city together", {
    expect_identical(
      cmd_parse("/jinx chapter-status Buenos Aires")$ref,
      "Buenos Aires"
    )
  })

  it("explains itself when given no reference", {
    parsed <- cmd_parse("/jinx chapter-status")
    expect_identical(parsed$action, "error")
    expect_match(parsed$message, "Usage")
  })
})

describe("chapter_resolve_ref", {
  it("treats digits as an issue number without a lookup", {
    expect_identical(chapter_resolve_ref("12", "rladies", "repo"), 12L)
  })

  it("looks up anything else by city", {
    local_mocked_bindings(chapter_find_issue = function(...) 7)
    expect_identical(chapter_resolve_ref("Oslo", "rladies", "repo"), 7)
  })
})
