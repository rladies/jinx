describe("jinx_commands registry", {
  it("labels every command with exactly one valid keyword", {
    keywords <- vapply(jinx_commands(), function(s) s$keyword, character(1))
    expect_true(all(keywords %in% c("jinx_safe", "jinx_gated")))
    expect_false(anyNA(keywords))
  })

  it("provides a one-argument handler for every command", {
    ok <- vapply(
      jinx_commands(),
      function(s) is.function(s$handler) && length(formals(s$handler)) == 1,
      logical(1)
    )
    expect_true(all(ok))
  })

  it("keeps the safe/gated classification stable", {
    safe <- names(Filter(
      function(s) identical(s$keyword, "jinx_safe"),
      jinx_commands()
    ))
    expect_setequal(
      safe,
      c(
        "help",
        "report",
        "report-chapters",
        "analytics",
        "website-analytics",
        "gha-dashboard",
        "contributors-list",
        "contributors-org",
        "events",
        "cfp-list",
        "chapter-health",
        "blog-check-links",
        "translate-status",
        "translate-validate",
        "poll-best",
        "error",
        "unknown"
      )
    )
  })

  it("registers every action cmd_parse can produce", {
    samples <- c(
      "/jinx help",
      "/jinx invite @a to website",
      "/jinx offboard @a from website",
      "/jinx slack-invite a@b.com",
      "/jinx report weekly",
      "/jinx announce https://x.com",
      "/jinx chapter-health",
      "/jinx blog-add https://x.com",
      "/jinx blog-check-links",
      "/jinx chapter-setup Oslo Norway",
      "/jinx chapter-update Oslo Norway",
      "/jinx report chapters",
      "/jinx gha-dashboard",
      "/jinx contributors jinx",
      "/jinx contributors update jinx",
      "/jinx contributors org",
      "/jinx events oslo",
      "/jinx events sync",
      "/jinx analytics",
      "/jinx website-analytics 30d",
      "/jinx cfp list",
      "/jinx cfp add conf 2026-01-01 https://x.com",
      "/jinx cfp recommend conf @speaker",
      "/jinx poll create Title days=2026-01-01 from=09:00 to=17:00 slot=30",
      "/jinx poll best abc123",
      "/jinx translate status",
      "/jinx translate validate en",
      "/jinx remind stale",
      "/jinx not-a-real-command"
    )
    actions <- vapply(samples, function(x) cmd_parse(x)$action, character(1))
    registered <- names(jinx_commands())
    expect_true(all(actions %in% registered))
  })
})

describe("command_is_privileged", {
  it("reads jinx_safe commands as not privileged", {
    expect_false(command_is_privileged("help"))
    expect_false(command_is_privileged("blog-check-links"))
    expect_false(command_is_privileged("poll-best"))
  })

  it("reads jinx_gated commands as privileged", {
    expect_true(command_is_privileged("invite"))
    expect_true(command_is_privileged("blog-add"))
    expect_true(command_is_privileged("poll-create"))
  })

  it("defaults unregistered or malformed actions to privileged", {
    expect_true(command_is_privileged("some-future-command"))
    expect_true(command_is_privileged(NULL))
    expect_true(command_is_privileged(character(0)))
  })
})
