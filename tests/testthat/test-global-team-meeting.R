describe("gt_onboarding_meeting_days", {
  it("returns two weeks of consecutive dates from the start", {
    days <- gt_onboarding_meeting_days(start = as.Date("2026-07-01"))
    expect_length(days, 14L)
    expect_identical(days[1], "2026-07-01")
    expect_identical(days[14], "2026-07-14")
    expect_true(all(diff(as.Date(days)) == 1))
  })

  it("defaults to a two-week window starting a week from today", {
    days <- gt_onboarding_meeting_days()
    expect_length(days, 14L)
    expect_identical(as.Date(days[1]), Sys.Date() + 7)
  })

  it("honours a custom number of weeks", {
    days <- gt_onboarding_meeting_days(start = as.Date("2026-07-01"), weeks = 1)
    expect_length(days, 7L)
    expect_identical(days[7], "2026-07-07")
  })
})

describe("gt_schedule_onboarding_meeting", {
  it("polls two weeks starting a week out and posts the URL", {
    poll_args <- NULL
    posted <- NULL
    local_mocked_bindings(
      meeting_poll_create = function(...) {
        poll_args <<- list(...)
        list(
          id = "abc123",
          url = "https://samkoma.org/p/abc123",
          edit_token = "tok"
        )
      },
      announce_post_reply = function(owner, repo, issue_number, body) {
        posted <<- list(
          owner = owner,
          repo = repo,
          issue_number = issue_number,
          body = body
        )
        invisible(NULL)
      }
    )

    url <- gt_schedule_onboarding_meeting(
      issue_number = 42,
      name = "Ada Lovelace",
      team_name = "Website",
      start = as.Date("2026-07-01")
    )

    expect_identical(url, "https://samkoma.org/p/abc123")
    expect_length(poll_args$days, 14L)
    expect_identical(poll_args$days[1], "2026-07-01")
    expect_identical(poll_args$days[14], "2026-07-14")
    expect_identical(poll_args$kind, "dates")
    expect_match(poll_args$title, "Ada Lovelace")
    expect_match(poll_args$title, "Website")
    expect_match(poll_args$title, "RLadies+")
  })

  it("posts the poll link to the onboarding issue", {
    posted <- NULL
    local_mocked_bindings(
      meeting_poll_create = function(...) {
        list(
          id = "abc123",
          url = "https://samkoma.org/p/abc123",
          edit_token = "tok"
        )
      },
      announce_post_reply = function(owner, repo, issue_number, body) {
        posted <<- list(
          owner = owner,
          repo = repo,
          issue_number = issue_number,
          body = body
        )
        invisible(NULL)
      }
    )

    gt_schedule_onboarding_meeting(
      issue_number = 42,
      name = "Ada Lovelace",
      team_name = "Website",
      org = "rladies"
    )

    expect_identical(posted$owner, "rladies")
    expect_identical(posted$repo, "global-team")
    expect_identical(posted$issue_number, 42)
    expect_true(grepl("samkoma.org/p/abc123", posted$body, fixed = TRUE))
  })
})

describe("gt_finalize_onboarding meeting poll", {
  it("opens an onboarding meeting poll for the created issue", {
    scheduled <- NULL
    local_mocked_bindings(
      load_teams_config = function() {
        list(default_assignees = "leadership")
      },
      team_get_by_slug = function(slug, config = NULL) {
        list(name = "Website", role = "maintainer", repos = character())
      },
      review_notify_teams = function(...) invisible(NULL),
      gt_schedule_onboarding_meeting = function(issue_number, name, ...) {
        scheduled <<- list(issue_number = issue_number, name = name)
        "https://samkoma.org/p/abc123"
      }
    )
    local_mocked_bindings(
      gh = function(endpoint, ...) {
        if (grepl("POST /repos/.*/issues$", endpoint)) {
          return(list(number = 7, html_url = "https://github.com/x/7"))
        }
        list()
      },
      .package = "gh"
    )

    gt_finalize_onboarding(
      username = "adalovelace",
      team = "website",
      name = "Ada Lovelace"
    )

    expect_identical(scheduled$issue_number, 7)
    expect_identical(scheduled$name, "Ada Lovelace")
  })

  it("still creates the issue when the poll fails", {
    local_mocked_bindings(
      load_teams_config = function() {
        list(default_assignees = "leadership")
      },
      team_get_by_slug = function(slug, config = NULL) {
        list(name = "Website", role = "maintainer", repos = character())
      },
      review_notify_teams = function(...) invisible(NULL),
      gt_schedule_onboarding_meeting = function(...) {
        cli::cli_abort("samkoma is down")
      }
    )
    local_mocked_bindings(
      gh = function(endpoint, ...) {
        if (grepl("POST /repos/.*/issues$", endpoint)) {
          return(list(number = 7, html_url = "https://github.com/x/7"))
        }
        list()
      },
      .package = "gh"
    )

    url <- suppressMessages(
      gt_finalize_onboarding(
        username = "adalovelace",
        team = "website",
        name = "Ada Lovelace"
      )
    )
    expect_identical(url, "https://github.com/x/7")
  })
})
