stale_issue <- function(body, updated = "2000-01-01T00:00:00Z") {
  list(
    number = 5,
    title = "Oslo, Norway chapter setup",
    html_url = "https://github.com/rladies/new-chapters-onboarding/issues/5",
    updated_at = updated,
    body = body
  )
}

pending_body <- paste(
  "#### Email",
  "",
  "The @rladies/email team will:",
  "",
  "-  [ ] create the chapter email",
  sep = "\n"
)

describe("chapter_nudge_body", {
  it("names the blocking team and the step they owe", {
    body <- chapter_nudge_body(chapter_checklist_parse(pending_body), 14)
    expect_match(body, "Waiting on @rladies/email", fixed = TRUE)
    expect_match(body, "create the chapter email")
    expect_match(body, "14 days")
  })

  it("falls back to the onboarding team when nobody is named", {
    body <- chapter_nudge_body(chapter_checklist_parse("- [ ] a step"), 14)
    expect_match(body, "Waiting on the onboarding team", fixed = TRUE)
  })
})

describe("chapter_nudge_issue", {
  cutoff <- as.Date("2026-01-01")

  it("stays quiet on an issue with recent activity", {
    posted <- FALSE
    local_mocked_bindings(
      announce_post_reply = function(...) posted <<- TRUE
    )
    result <- chapter_nudge_issue(
      stale_issue(pending_body, "2026-06-01T00:00:00Z"),
      cutoff,
      14,
      "rladies",
      "new-chapters-onboarding"
    )
    expect_null(result)
    expect_false(posted)
  })

  it("stays quiet when the checklist is already complete", {
    posted <- FALSE
    local_mocked_bindings(
      announce_post_reply = function(...) posted <<- TRUE
    )
    result <- chapter_nudge_issue(
      stale_issue("- [x] all done"),
      cutoff,
      14,
      "rladies",
      "new-chapters-onboarding"
    )
    expect_null(result)
    expect_false(posted)
  })

  it("comments on a stale issue with unfinished steps", {
    body <- NULL
    local_mocked_bindings(
      announce_post_reply = function(org, repo, number, text) body <<- text
    )
    result <- chapter_nudge_issue(
      stale_issue(pending_body),
      cutoff,
      14,
      "rladies",
      "new-chapters-onboarding"
    )
    expect_identical(result$number, 5)
    expect_match(body, "@rladies/email", fixed = TRUE)
  })
})

describe("chapter_remind_stale", {
  it("nudges once per stale issue across both labels", {
    local_mocked_bindings(
      gh = function(endpoint, ...) {
        args <- list(...)
        if (identical(args$labels, "new chapter")) {
          list(stale_issue(pending_body))
        } else {
          list()
        }
      },
      .package = "gh"
    )
    local_mocked_bindings(announce_post_reply = function(...) invisible(NULL))
    expect_message(nudged <- chapter_remind_stale())
    expect_length(nudged, 1)
  })
})
