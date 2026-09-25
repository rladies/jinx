describe("chapter_confirm_body", {
  it("names the chapter and the things that now exist", {
    body <- chapter_confirm_body(
      "Oslo",
      "oslo@rladies.org",
      "https://www.meetup.com/rladies-oslo/"
    )
    expect_match(body, "RLadies+ Oslo", fixed = TRUE)
    expect_match(body, "oslo@rladies.org", fixed = TRUE)
    expect_match(body, "rladies-oslo", fixed = TRUE)
  })

  it("says so rather than leaving a placeholder when something is missing", {
    body <- chapter_confirm_body("Oslo")
    expect_false(grepl("<EMAIL>", body, fixed = TRUE))
    expect_false(grepl("<MEETUP_URL>", body, fixed = TRUE))
    expect_match(body, "not set up yet")
    expect_match(body, "not created yet")
  })

  it("carries the activity rule and the security guidance", {
    body <- chapter_confirm_body("Oslo")
    expect_match(body, "six months")
    expect_match(body, "password manager")
    expect_match(body, "two-factor")
  })
})

describe("chapter_outstanding_items", {
  it("lists only the unticked items", {
    state <- chapter_checklist_parse(
      "- [x] done\n- [ ] not done\n- [ ] also not"
    )
    expect_identical(
      chapter_outstanding_items(state),
      c("not done", "also not")
    )
  })

  it("is empty for a complete checklist", {
    state <- chapter_checklist_parse("- [x] done")
    expect_length(chapter_outstanding_items(state), 0)
  })

  it("is empty when there is no checklist", {
    expect_length(chapter_outstanding_items(chapter_checklist_empty()), 0)
  })
})

describe("chapter_confirm_send", {
  complete <- function(...) chapter_checklist_parse("- [x] all done")
  incomplete <- function(...) {
    chapter_checklist_parse("- [x] done\n- [ ] create the chapter email")
  }

  it("refuses without a valid address, before doing anything else", {
    sent <- FALSE
    local_mocked_bindings(mail_send = function(...) sent <<- TRUE)
    expect_error(chapter_confirm_send(5, character(0)), "at least one valid")
    expect_error(chapter_confirm_send(5, "not-an-email"), "Not an email")
    expect_false(sent)
  })

  it("refuses while checklist steps are outstanding", {
    sent <- FALSE
    local_mocked_bindings(
      chapter_meta_fetch = function(...) list(city = "Oslo"),
      chapter_onboard_state = incomplete,
      mail_send = function(...) sent <<- TRUE
    )
    expect_error(
      chapter_confirm_send(5, "a@example.com"),
      "still outstanding"
    )
    expect_false(sent)
  })

  it("names the first outstanding step so it can be chased", {
    local_mocked_bindings(
      chapter_meta_fetch = function(...) list(city = "Oslo"),
      chapter_onboard_state = incomplete
    )
    expect_error(
      chapter_confirm_send(5, "a@example.com"),
      "create the chapter email"
    )
  })

  it("sends when the checklist is complete", {
    args <- NULL
    local_mocked_bindings(
      chapter_meta_fetch = function(...) list(city = "Oslo"),
      chapter_onboard_state = complete,
      mail_send = function(...) {
        args <<- list(...)
        "msg1"
      },
      announce_post_reply = function(...) invisible(NULL)
    )
    id <- chapter_confirm_send(5, "a@example.com")
    expect_identical(id, "msg1")
    expect_match(args$subject, "RLadies+ Oslo is set up", fixed = TRUE)
  })

  it("sends with force despite outstanding steps, and says so on the issue", {
    posted <- NULL
    local_mocked_bindings(
      chapter_meta_fetch = function(...) list(city = "Oslo"),
      chapter_onboard_state = incomplete,
      mail_send = function(...) "msg1",
      announce_post_reply = function(org, repo, number, body) posted <<- body
    )
    chapter_confirm_send(5, "a@example.com", force = TRUE)
    expect_match(posted, "still unticked")
  })

  it("records how many organisers were written to, not their addresses", {
    posted <- NULL
    local_mocked_bindings(
      chapter_meta_fetch = function(...) list(city = "Oslo"),
      chapter_onboard_state = complete,
      mail_send = function(...) "msg1",
      announce_post_reply = function(org, repo, number, body) posted <<- body
    )
    chapter_confirm_send(5, c("a@example.com", "b@example.com"))
    expect_match(posted, "2 organisers")
    expect_false(grepl("a@example.com", posted, fixed = TRUE))
  })

  it("refuses when the issue carries no chapter block", {
    local_mocked_bindings(chapter_meta_fetch = function(...) NULL)
    expect_error(
      chapter_confirm_send(5, "a@example.com"),
      "without knowing the chapter"
    )
  })
})
