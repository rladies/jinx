provision_state <- function(website_done = FALSE) {
  data.frame(
    section = "Add the chapter to the website",
    owner = NA_character_,
    item = "add prospective chapter to the current chapters on the website",
    done = website_done,
    stringsAsFactors = FALSE
  )
}

local_provision <- function(
  meta = list(city = "Oslo", country = "Norway", region = NULL),
  found = list(urlname = "rladies-oslo", email = NULL, meetup_url = NULL),
  state = provision_state(),
  env = parent.frame(),
  ...
) {
  calls <- new.env(parent = emptyenv())
  calls$comment <- NULL
  defaults <- list(
    chapter_meta_fetch = function(...) meta,
    chapter_thread_scan = function(...) found,
    chapter_onboard_state = function(...) state,
    chapter_onboard_website = function(...) "https://example.com/pr/1",
    chapter_team_create = function(...) "oslo",
    chapter_team_slug = function(...) "oslo",
    chapter_repo_create = function(...) "meetup-presentations_oslo",
    chapter_meetup_logo_upload = function(...) invisible(TRUE),
    announce_post_reply = function(owner, repo, issue_number, body) {
      calls$comment <- body
      invisible(NULL)
    }
  )
  bindings <- utils::modifyList(defaults, list(...))
  do.call(
    local_mocked_bindings,
    c(bindings, list(.env = env))
  )
  calls
}

describe("provision_is_done", {
  it("is TRUE when every matching item is ticked", {
    expect_true(provision_is_done(provision_state(TRUE), "on the website"))
  })

  it("is FALSE when a matching item is unticked", {
    expect_false(provision_is_done(provision_state(FALSE), "on the website"))
  })

  it("is FALSE when nothing matches", {
    expect_false(provision_is_done(provision_state(TRUE), "no such step"))
  })

  it("is FALSE for an empty checklist", {
    expect_false(provision_is_done(chapter_checklist_empty(), "anything"))
  })
})

describe("provision_try", {
  it("records a successful step", {
    row <- provision_try("Thing", function() "did it")
    expect_identical(row$status, "done")
    expect_identical(row$detail, "did it")
  })

  it("records a failure instead of raising it", {
    expect_message(row <- provision_try("Thing", function() stop("nope")))
    expect_identical(row$status, "failed")
    expect_match(row$detail, "nope")
  })
})

describe("chapter_provision", {
  it("runs every step it can and reports them", {
    calls <- local_provision()
    report <- chapter_provision(7)
    expect_identical(
      report$step,
      c("Website entry", "GitHub team", "Presentations repo", "Meetup photo")
    )
    expect_identical(
      report$status,
      c("done", "done", "skipped", "done")
    )
    expect_match(calls$comment, "Oslo, Norway", fixed = TRUE)
  })

  it("waits for the Meetup group before the steps that need it", {
    local_provision(
      found = list(urlname = NULL, email = NULL, meetup_url = NULL)
    )
    report <- chapter_provision(7)
    waiting <- report$status == "waiting"
    expect_identical(
      report$step[waiting],
      c("GitHub team", "Meetup photo")
    )
    expect_identical(report$status[report$step == "Website entry"], "done")
  })

  it("creates the presentations repo only when asked", {
    local_provision()
    report <- chapter_provision(7, presentations_repo = TRUE)
    expect_identical(
      report$status[report$step == "Presentations repo"],
      "done"
    )
  })

  it("skips the website when it is already on the checklist", {
    local_provision(state = provision_state(TRUE))
    report <- chapter_provision(7)
    expect_identical(report$status[report$step == "Website entry"], "skipped")
  })

  it("carries on when one step fails", {
    local_provision(
      chapter_team_create = function(...) stop("team already exists elsewhere")
    )
    expect_message(report <- chapter_provision(7))
    expect_identical(report$status[report$step == "GitHub team"], "failed")
    expect_identical(report$status[report$step == "Meetup photo"], "done")
  })

  it("refuses an issue with no chapter details", {
    local_provision(meta = NULL)
    expect_error(chapter_provision(7), "no readable chapter details")
  })

  it("refuses an issue with a half-filled block", {
    local_provision(meta = list(city = "Oslo", country = NULL))
    expect_error(chapter_provision(7), "no readable chapter details")
  })
})

describe("chapter_provision_report", {
  it("tells the team what to do next when a step is waiting", {
    report <- rbind(
      provision_step("Website entry", "done", "opened a PR"),
      provision_step("GitHub team", "waiting", "no Meetup group yet")
    )
    body <- chapter_provision_report(
      report,
      list(city = "Oslo", country = "Norway"),
      list(urlname = NULL, email = NULL)
    )
    expect_match(body, "Waiting on the Meetup group", fixed = TRUE)
    expect_match(body, "| Website entry | opened a PR |", fixed = TRUE)
  })

  it("points at the failure when a step failed", {
    report <- provision_step("GitHub team", "failed", "boom")
    body <- chapter_provision_report(
      report,
      list(city = "Oslo", country = "Norway"),
      list(urlname = "rladies-oslo", email = NULL)
    )
    expect_match(body, "Some steps failed", fixed = TRUE)
  })

  it("says so when there is nothing left to do", {
    report <- provision_step("GitHub team", "done", "made it")
    body <- chapter_provision_report(
      report,
      list(city = "Oslo", country = "Norway"),
      list(urlname = "rladies-oslo", email = "oslo@rladies.org")
    )
    expect_match(body, "everything jinx can set up", fixed = TRUE)
    expect_match(body, "oslo@rladies.org", fixed = TRUE)
  })
})
