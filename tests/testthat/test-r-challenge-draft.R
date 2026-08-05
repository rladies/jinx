draft_build_fixture <- function(difficulty = "beginner") {
  list(
    challenge = list(
      title = "Double it",
      difficulty = difficulty,
      statement = "# Write double(x): x times two.\nx <- 2\n# should return:\n4",
      solution = "double <- function(x) x * 2",
      tests = c("identical(double(2), 4)")
    ),
    statement = c(
      "``` r",
      "x <- 2",
      "# should return:",
      "4",
      "#> [1] 4",
      "```"
    ),
    reprex = c("double <- function(x) x * 2"),
    critique = list(ok = TRUE, verdict = "approve", issues = character()),
    attempts = 1L
  )
}

describe("r_challenge_open_issue()", {
  it("creates a proposed issue with source and themed difficulty labels", {
    captured <- NULL
    local_mocked_bindings(
      gh = function(endpoint, ...) {
        captured <<- list(endpoint = endpoint, args = list(...))
        list(html_url = "https://github.com/rladies/cauldron/issues/1")
      },
      .package = "gh"
    )

    url <- r_challenge_open_issue(draft_build_fixture("advanced"))

    expect_match(url, "issues/1", fixed = TRUE)
    args <- captured$args
    expect_identical(captured$endpoint, "POST /repos/{owner}/{repo}/issues")
    expect_identical(args$owner, "rladies")
    expect_identical(args$repo, "cauldron")
    labels <- unlist(args$labels)
    expect_true("status: proposed" %in% labels)
    expect_true("source: ai" %in% labels)
    expect_true("difficulty: Oracle" %in% labels)
    expect_match(args$title, "Double it", fixed = TRUE)
    expect_match(args$body, "Reference solution", fixed = TRUE)
  })

  it("maps each difficulty key to its themed label", {
    captured <- NULL
    local_mocked_bindings(
      gh = function(endpoint, ...) {
        captured <<- list(...)
        list(html_url = "u")
      },
      .package = "gh"
    )
    r_challenge_open_issue(draft_build_fixture("beginner"))
    expect_true("difficulty: Novice" %in% unlist(captured$labels))
    r_challenge_open_issue(draft_build_fixture("intermediate"))
    expect_true("difficulty: Adept" %in% unlist(captured$labels))
  })

  it("honours a custom repo and source", {
    captured <- NULL
    local_mocked_bindings(
      gh = function(endpoint, ...) {
        captured <<- list(...)
        list(html_url = "u")
      },
      .package = "gh"
    )
    r_challenge_open_issue(
      draft_build_fixture(),
      repo = "rladies/testpot",
      source = "community"
    )
    expect_identical(captured$owner, "rladies")
    expect_identical(captured$repo, "testpot")
    expect_true("source: community" %in% unlist(captured$labels))
  })
})

describe("r_challenge_draft_post()", {
  it("opens an issue when a verified challenge is produced", {
    opened <- FALSE
    local_mocked_bindings(
      r_challenge_draft_build = function(...) draft_build_fixture(),
      r_challenge_open_issue = function(build, ...) {
        opened <<- TRUE
        "https://github.com/rladies/cauldron/issues/2"
      }
    )
    expect_true(r_challenge_draft_post())
    expect_true(opened)
  })

  it("does nothing when no challenge passes verification", {
    opened <- FALSE
    local_mocked_bindings(
      r_challenge_draft_build = function(...) NULL,
      r_challenge_open_issue = function(build, ...) {
        opened <<- TRUE
        "u"
      }
    )
    expect_message(
      res <- r_challenge_draft_post(),
      "No verified challenge"
    )
    expect_false(res)
    expect_false(opened)
  })
})
