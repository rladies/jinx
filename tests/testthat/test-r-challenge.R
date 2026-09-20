good_json <- function() {
  paste0(
    "Here's this week's challenge:\n```json\n",
    '{"title":"Double it","difficulty":"Beginner",',
    '"statement":"# Write double(x): x times two.\\nx <- 2\\n',
    '# double(x) should return:\\n4",',
    '"solution":"double <- function(x) x * 2",',
    '"tests":["identical(double(2), 4)","identical(double(0), 0)"]}',
    "\n```\nGood luck!"
  )
}

sample_challenge <- function() {
  list(
    title = "Double it",
    difficulty = "beginner",
    statement = paste0(
      "# Write double(x): x times two.\n",
      "x <- 2\n# double(x) should return:\n4"
    ),
    solution = "double <- function(x) x * 2",
    tests = c("identical(double(2), 4)", "identical(double(0), 0)")
  )
}

sample_build <- function() {
  list(
    challenge = sample_challenge(),
    statement = c(
      "``` r",
      "# Write double(x): x times two.",
      "x <- 2",
      "# double(x) should return:",
      "4",
      "#> [1] 4",
      "```"
    ),
    reprex = c(
      "double <- function(x) x * 2",
      "base::stopifnot(identical(double(2), 4))"
    ),
    critique = list(ok = TRUE, verdict = "approve", issues = character()),
    attempts = 1L
  )
}

describe("r_challenge_difficulties()", {
  it("defines three ordered levels", {
    d <- r_challenge_difficulties()
    expect_identical(d$level, c("beginner", "intermediate", "advanced"))
  })

  it("maps a level to its badge and label", {
    expect_identical(
      r_challenge_difficulty_badge("advanced"),
      intToUtf8(0x1F534)
    )
    expect_identical(
      r_challenge_difficulty_badge("beginner"),
      intToUtf8(0x1F7E2)
    )
    expect_identical(r_challenge_difficulty_label("advanced"), "Oracle")
  })

  it("errors on an unknown level", {
    expect_error(
      r_challenge_difficulty_badge("wizard"),
      "Unknown challenge difficulty"
    )
  })
})

describe("r_challenge_parse()", {
  it("parses a well-formed challenge wrapped in prose and a code fence", {
    ch <- r_challenge_parse(good_json())
    expect_identical(ch$title, "Double it")
    expect_identical(ch$difficulty, "beginner")
    expect_identical(length(ch$tests), 2L)
    expect_match(ch$statement, "double(x) should return", fixed = TRUE)
    expect_identical(ch$solution, "double <- function(x) x * 2")
  })

  it("returns NULL when a required field is missing", {
    text <- paste0(
      '{"title":"x","difficulty":"beginner",',
      '"solution":"sol","tests":["TRUE"]}'
    )
    expect_null(r_challenge_parse(text))
  })

  it("returns NULL for an unknown difficulty", {
    text <- paste0(
      '{"title":"x","difficulty":"wizard","statement":"s","sample":"s",',
      '"solution":"sol","tests":["TRUE"]}'
    )
    expect_null(r_challenge_parse(text))
  })

  it("returns NULL when tests are empty", {
    text <- paste0(
      '{"title":"x","difficulty":"beginner","statement":"s",',
      '"solution":"sol","tests":[]}'
    )
    expect_null(r_challenge_parse(text))
  })

  it("returns NULL when the output is not JSON", {
    expect_null(r_challenge_parse("I could not think of one, sorry"))
    expect_null(r_challenge_parse(""))
    expect_null(r_challenge_parse(NULL))
  })
})

describe("r_challenge_reprex_check()", {
  it("passes when the runner reports no error", {
    res <- r_challenge_reprex_check(
      "double <- function(x) x * 2",
      "identical(double(2), 4)",
      runner = function(code) c("double <- function(x) x * 2", "identical(2)")
    )
    expect_true(res$ok)
  })

  it("fails when the runner output contains an error line", {
    res <- r_challenge_reprex_check(
      "double <- function(x) x * 3",
      "identical(double(2), 4)",
      runner = function(code) c("double <- function(x) x * 3", "#> Error: no")
    )
    expect_false(res$ok)
  })

  it("fails when there are no tests", {
    res <- r_challenge_reprex_check(
      "x <- 1",
      character(),
      runner = function(code) ""
    )
    expect_false(res$ok)
  })

  it("fails closed when the runner errors, e.g. a timeout", {
    res <- r_challenge_reprex_check(
      "x <- 1",
      "TRUE",
      runner = function(code) stop("reached elapsed time limit")
    )
    expect_false(res$ok)
    expect_match(res$output, "elapsed time limit")
  })

  it("verifies a real solution end to end with reprex", {
    skip_if_not_installed("reprex")
    skip_if_not_installed("callr")
    pass <- r_challenge_reprex_check(
      "add_one <- function(x) x + 1",
      "identical(add_one(1), 2)"
    )
    expect_true(pass$ok)
    fail <- r_challenge_reprex_check(
      "add_one <- function(x) x + 2",
      "identical(add_one(1), 2)"
    )
    expect_false(fail$ok)
  })

  it("keeps only locale/path/lib env vars and drops secrets", {
    got <- r_challenge_env_keep(c(
      "PATH",
      "HOME",
      "LC_ALL",
      "R_LIBS_USER",
      "CLOUDFLARE_API_TOKEN",
      "SHORTIO",
      "AIRTABLE_PAT"
    ))
    expect_identical(got, c(TRUE, TRUE, TRUE, TRUE, FALSE, FALSE, FALSE))
  })

  it("does not leak operator secrets into the verification session", {
    skip_if_not_installed("reprex")
    skip_if_not_installed("callr")
    withr::local_envvar(c(
      SHORTIO = "leaky-shortio",
      MY_API_TOKEN = "leaky-token"
    ))
    res <- r_challenge_reprex_check(
      paste0(
        "peek <- function() ",
        "paste0(Sys.getenv('SHORTIO'), Sys.getenv('MY_API_TOKEN'))"
      ),
      "identical(peek(), '')"
    )
    expect_true(res$ok)
  })

  it("is not fooled by a solution that redefines stopifnot", {
    skip_if_not_installed("reprex")
    skip_if_not_installed("callr")
    res <- r_challenge_reprex_check(
      "stopifnot <- function(...) invisible(TRUE)\nf <- function() 1",
      "identical(f(), 999L)"
    )
    expect_false(res$ok)
  })
})

describe("r_challenge_render_statement()", {
  it("returns ok with the rendered lines when the statement runs", {
    res <- r_challenge_render_statement(
      "x <- 1\nx",
      runner = function(code) c("``` r", "x <- 1", "x", "#> [1] 1", "```")
    )
    expect_true(res$ok)
    expect_true(any(grepl("#>", res$rendered, fixed = TRUE)))
  })

  it("fails when the statement errors (e.g. calls the unwritten function)", {
    res <- r_challenge_render_statement(
      "square_evens(x)",
      runner = function(code) {
        c("``` r", "square_evens(x)", "#> Error: nope", "```")
      }
    )
    expect_false(res$ok)
  })

  it("fails closed when the runner errors", {
    res <- r_challenge_render_statement(
      "x",
      runner = function(code) stop("timeout")
    )
    expect_false(res$ok)
  })

  it("renders a real statement end to end with reprex", {
    skip_if_not_installed("reprex")
    skip_if_not_installed("callr")
    ok <- r_challenge_render_statement("x <- c(1, 2, 3)\nrev(x)")
    expect_true(ok$ok)
    expect_true(any(grepl("#>", ok$rendered, fixed = TRUE)))
    bad <- r_challenge_render_statement("no_such_function_here(1)")
    expect_false(bad$ok)
  })
})

describe("r_challenge_adversarial_check()", {
  it("approves when the reviewer returns approve", {
    local_mocked_bindings(
      cloudflare_generate = function(...) '{"verdict":"approve","issues":[]}'
    )
    res <- r_challenge_adversarial_check(sample_challenge(), "output")
    expect_true(res$ok)
    expect_identical(res$verdict, "approve")
  })

  it("rejects and keeps the issues when the reviewer returns reject", {
    local_mocked_bindings(
      cloudflare_generate = function(...) {
        '{"verdict":"reject","issues":["ambiguous","wrong difficulty"]}'
      }
    )
    res <- r_challenge_adversarial_check(sample_challenge(), "output")
    expect_false(res$ok)
    expect_identical(res$issues, c("ambiguous", "wrong difficulty"))
  })

  it("fails closed on unparseable reviewer output", {
    local_mocked_bindings(
      cloudflare_generate = function(...) "no json here"
    )
    res <- r_challenge_adversarial_check(sample_challenge(), "output")
    expect_false(res$ok)
  })

  it("fails closed and warns when the review call errors", {
    local_mocked_bindings(
      cloudflare_generate = function(...) stop("network down")
    )
    expect_warning(
      res <- r_challenge_adversarial_check(sample_challenge(), "output"),
      "adversarial check failed"
    )
    expect_false(res$ok)
  })
})

describe("r_challenge_draft_build()", {
  it("returns a verified challenge on the first good draft", {
    local_mocked_bindings(
      r_challenge_generate = function(...) good_json(),
      r_challenge_reprex_check = function(solution, tests, ...) {
        list(ok = TRUE, output = "ok")
      },
      r_challenge_render_statement = function(statement, ...) {
        list(ok = TRUE, rendered = c("``` r", "x <- 2", "```"))
      },
      r_challenge_adversarial_check = function(...) {
        list(ok = TRUE, verdict = "approve", issues = character())
      }
    )
    build <- r_challenge_draft_build()
    expect_identical(build$attempts, 1L)
    expect_identical(build$challenge$title, "Double it")
    expect_true(any(grepl("x <- 2", build$statement, fixed = TRUE)))
  })

  it("regenerates when the reference solution fails verification", {
    calls <- 0L
    local_mocked_bindings(
      r_challenge_generate = function(...) good_json(),
      r_challenge_reprex_check = function(solution, tests, ...) {
        calls <<- calls + 1L
        list(ok = calls > 1L, output = "out")
      },
      r_challenge_render_statement = function(...) {
        list(ok = TRUE, rendered = "x")
      },
      r_challenge_adversarial_check = function(...) {
        list(ok = TRUE, verdict = "approve", issues = character())
      }
    )
    expect_message(
      build <- r_challenge_draft_build(max_tries = 2L),
      "failed reprex verification"
    )
    expect_identical(build$attempts, 2L)
  })

  it("regenerates when the statement does not render", {
    local_mocked_bindings(
      r_challenge_generate = function(...) good_json(),
      r_challenge_reprex_check = function(...) list(ok = TRUE, output = "ok"),
      r_challenge_render_statement = function(...) {
        list(ok = FALSE, rendered = "boom")
      },
      r_challenge_adversarial_check = function(...) {
        list(ok = TRUE, verdict = "approve", issues = character())
      }
    )
    expect_warning(
      expect_message(
        build <- r_challenge_draft_build(max_tries = 1L),
        "statement did not render"
      ),
      "No verified challenge"
    )
    expect_null(build)
  })

  it("rejects a challenge the adversarial reviewer flags, then gives up", {
    local_mocked_bindings(
      r_challenge_generate = function(...) good_json(),
      r_challenge_reprex_check = function(...) list(ok = TRUE, output = "ok"),
      r_challenge_render_statement = function(...) {
        list(ok = TRUE, rendered = "x")
      },
      r_challenge_adversarial_check = function(...) {
        list(ok = FALSE, verdict = "reject", issues = "ambiguous")
      }
    )
    expect_warning(
      expect_message(
        build <- r_challenge_draft_build(max_tries = 1L),
        "adversarial review"
      ),
      "No verified challenge"
    )
    expect_null(build)
  })

  it("regenerates when the model output is not a valid challenge", {
    local_mocked_bindings(
      r_challenge_generate = function(...) "not json at all",
      r_challenge_reprex_check = function(...) list(ok = TRUE, output = "ok"),
      r_challenge_render_statement = function(...) {
        list(ok = TRUE, rendered = "x")
      },
      r_challenge_adversarial_check = function(...) {
        list(ok = TRUE, verdict = "approve", issues = character())
      }
    )
    expect_warning(
      expect_message(
        build <- r_challenge_draft_build(max_tries = 1L),
        "not a valid challenge"
      ),
      "No verified challenge"
    )
    expect_null(build)
  })
})

describe("r_challenge_format_slack()", {
  statement_lines <- function() {
    c("``` r", "x <- 2", "# should return:", "4", "#> [1] 4", "```")
  }

  it("includes the difficulty badge, tier label, title, and statement", {
    out <- r_challenge_format_slack("Double it", "beginner", statement_lines())
    expect_match(out, intToUtf8(0x1F7E2), fixed = TRUE)
    expect_match(out, "Novice", fixed = TRUE)
    expect_match(out, "brewing in the cauldron", fixed = TRUE)
    expect_match(out, "Double it", fixed = TRUE)
    expect_match(out, "should return", fixed = TRUE)
    expect_match(out, "#> [1] 4", fixed = TRUE)
  })

  it("strips the reprex language tag and never reveals a solution", {
    out <- r_challenge_format_slack("t", "beginner", statement_lines())
    expect_false(grepl("``` r", out, fixed = TRUE))
    expect_false(grepl("function", out, fixed = TRUE))
  })

  it("escapes injected Slack control sequences in the title", {
    out <- r_challenge_format_slack("Ping <!channel>", "beginner", "x")
    expect_false(grepl("<!channel>", out, fixed = TRUE))
  })
})

describe("r_challenge_format_issue() and r_challenge_issue_title()", {
  it("titles the issue with the challenge name and difficulty", {
    title <- r_challenge_issue_title(sample_challenge())
    expect_match(title, "Double it", fixed = TRUE)
    expect_match(title, "beginner", fixed = TRUE)
  })

  it("shows the statement and hides the solution and verification in details", {
    body <- r_challenge_format_issue(sample_build())
    expect_match(body, "should return", fixed = TRUE)
    expect_match(body, "Reference solution", fixed = TRUE)
    expect_match(body, "double <- function(x) x * 2", fixed = TRUE)
    expect_match(body, "Adversarial review", fixed = TRUE)
    expect_match(body, "status:approved", fixed = TRUE)
    expect_match(body, "approve", fixed = TRUE)
  })
})
