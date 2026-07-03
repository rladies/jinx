fake_config <- list(
  grimoire = list(
    gates = list(
      brand = "run-brand-check",
      blog = "run-blog-review",
      social = "run-social-review",
      translation = "run-translation-review"
    )
  )
)

describe("parse_pr_ref", {
  it("parses owner/repo#number", {
    ref <- parse_pr_ref("rladies/website#42")
    expect_identical(ref$owner, "rladies")
    expect_identical(ref$repo, "website")
    expect_identical(ref$number, 42L)
  })

  it("parses a full pull request URL", {
    ref <- parse_pr_ref("https://github.com/rladies/website/pull/7")
    expect_identical(ref$owner, "rladies")
    expect_identical(ref$repo, "website")
    expect_identical(ref$number, 7L)
  })

  it("parses a bare number against the default repo", {
    ref <- parse_pr_ref("#5", default_owner = "rladies", default_repo = "jinx")
    expect_identical(ref$owner, "rladies")
    expect_identical(ref$repo, "jinx")
    expect_identical(ref$number, 5L)
  })

  it("defaults the repo from GITHUB_REPOSITORY", {
    withr::local_envvar(GITHUB_REPOSITORY = "rladies/directory")
    ref <- parse_pr_ref("12")
    expect_identical(ref$owner, "rladies")
    expect_identical(ref$repo, "directory")
    expect_identical(ref$number, 12L)
  })

  it("returns NULL for unparseable references", {
    expect_null(parse_pr_ref("not a pr"))
    expect_null(parse_pr_ref(""))
  })
})

describe("command_default_repo", {
  it("splits GITHUB_REPOSITORY into owner and repo", {
    withr::local_envvar(GITHUB_REPOSITORY = "rladies/blog")
    repo <- command_default_repo()
    expect_identical(repo$owner, "rladies")
    expect_identical(repo$repo, "blog")
  })

  it("falls back to rladies/jinx when unset", {
    withr::local_envvar(GITHUB_REPOSITORY = "")
    repo <- command_default_repo()
    expect_identical(repo$owner, "rladies")
    expect_identical(repo$repo, "jinx")
  })
})

describe("copilot_gate_label", {
  it("names the grimoire skill behind a gate", {
    expect_identical(
      as.character(copilot_gate_label("blog", fake_config)),
      "blog (run-blog-review)"
    )
  })

  it("describes a full review when no gate is given", {
    expect_match(copilot_gate_label(NULL, fake_config), "brand & voice")
  })
})

describe("copilot_request_review", {
  it("requests the Copilot reviewer login and returns TRUE", {
    captured <- NULL
    local_mocked_bindings(
      gh = function(endpoint, ...) {
        captured <<- list(endpoint = endpoint, args = list(...))
        list()
      },
      .package = "gh"
    )
    ok <- copilot_request_review("rladies", "website", 3L)
    expect_true(ok)
    expect_match(captured$endpoint, "requested_reviewers")
    expect_identical(
      captured$args$reviewers,
      list("copilot-pull-request-reviewer[bot]")
    )
  })

  it("returns FALSE when the request errors", {
    local_mocked_bindings(
      gh = function(endpoint, ...) stop("not enabled"),
      .package = "gh"
    )
    expect_false(copilot_request_review("rladies", "website", 3L))
  })
})

describe("copilot_review_pr", {
  it("posts a scoping comment and returns a summon message on success", {
    posted <- NULL
    local_mocked_bindings(copilot_request_review = function(...) TRUE)
    local_mocked_bindings(
      gh = function(endpoint, ...) {
        posted <<- list(...)$body
        list()
      },
      .package = "gh"
    )
    msg <- copilot_review_pr(
      "rladies",
      "website",
      42L,
      gate = "brand",
      config = fake_config
    )
    expect_match(msg, "Summoned Copilot")
    expect_match(msg, "rladies/website#42")
    expect_match(posted, "review gate")
  })

  it("returns a failure message and posts nothing when the request fails", {
    posted <- FALSE
    local_mocked_bindings(copilot_request_review = function(...) FALSE)
    local_mocked_bindings(
      gh = function(endpoint, ...) {
        posted <<- TRUE
        list()
      },
      .package = "gh"
    )
    msg <- copilot_review_pr(
      "rladies",
      "website",
      42L,
      gate = "blog",
      config = fake_config
    )
    expect_match(msg, "didn't go through")
    expect_false(posted)
  })
})
