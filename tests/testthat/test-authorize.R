describe("command_is_privileged", {
  it("treats read-only commands as safe", {
    expect_false(command_is_privileged("help"))
    expect_false(command_is_privileged("report"))
    expect_false(command_is_privileged("analytics"))
    expect_false(command_is_privileged("poll-best"))
  })

  it("treats mutating commands as privileged", {
    expect_true(command_is_privileged("invite"))
    expect_true(command_is_privileged("offboard"))
    expect_true(command_is_privileged("poll-create"))
    expect_true(command_is_privileged("slack-invite"))
  })

  it("defaults unknown or newly added actions to privileged", {
    expect_true(command_is_privileged("some-future-command"))
  })
})

describe("normalize_handle", {
  it("lower-cases, trims, and strips a leading @", {
    expect_identical(normalize_handle("  @DrMowinckels "), "drmowinckels")
    expect_identical(normalize_handle("Octocat"), "octocat")
  })
})

describe("gt_actor_is_authorized", {
  directory <- function() {
    list(
      list(
        fields = list(
          `GitHub handle` = "DrMowinckels",
          organiser_slack = "amowinckel"
        )
      ),
      list(
        fields = list(`GitHub handle` = "octocat", organiser_slack = "octo")
      ),
      list(fields = list(organiser_slack = "slackonly"))
    )
  }

  it("matches a GitHub username case-insensitively", {
    local_mocked_bindings(
      airtable_list_records = function(base_id, table, api_key) directory()
    )
    expect_true(gt_actor_is_authorized("github", "drmowinckels", api_key = "k"))
    expect_true(gt_actor_is_authorized("github", "@Octocat", api_key = "k"))
  })

  it("matches a Slack username", {
    local_mocked_bindings(
      airtable_list_records = function(base_id, table, api_key) directory()
    )
    expect_true(gt_actor_is_authorized("slack", "amowinckel", api_key = "k"))
    expect_true(gt_actor_is_authorized("slack", "slackonly", api_key = "k"))
  })

  it("rejects an actor absent from the directory", {
    local_mocked_bindings(
      airtable_list_records = function(base_id, table, api_key) directory()
    )
    expect_false(gt_actor_is_authorized("github", "stranger", api_key = "k"))
    expect_false(gt_actor_is_authorized("slack", "nobody", api_key = "k"))
  })

  it("does not match a Slack handle against the GitHub column", {
    local_mocked_bindings(
      airtable_list_records = function(base_id, table, api_key) directory()
    )
    expect_false(gt_actor_is_authorized("github", "amowinckel", api_key = "k"))
  })

  it("rejects an empty actor without hitting Airtable", {
    called <- FALSE
    local_mocked_bindings(
      airtable_list_records = function(base_id, table, api_key) {
        called <<- TRUE
        directory()
      }
    )
    expect_false(gt_actor_is_authorized("github", "", api_key = "k"))
    expect_false(called)
  })

  it("aborts when no API key is available", {
    expect_error(
      gt_actor_is_authorized("github", "octocat", api_key = ""),
      "AIRTABLE_API_KEY"
    )
  })
})

describe("cmd_authorize", {
  it("allows a NULL command", {
    expect_true(cmd_authorize(NULL, actor = "x", source = "github")$ok)
  })

  it("allows safe commands without consulting the directory", {
    called <- FALSE
    local_mocked_bindings(
      gt_actor_is_authorized = function(...) {
        called <<- TRUE
        TRUE
      }
    )
    res <- cmd_authorize(list(action = "help"), actor = "", source = "slack")
    expect_true(res$ok)
    expect_false(called)
  })

  it("allows a privileged command from a directory member", {
    local_mocked_bindings(
      gt_actor_is_authorized = function(source, actor, ...) TRUE
    )
    res <- cmd_authorize(
      list(action = "invite"),
      actor = "ada",
      source = "github"
    )
    expect_true(res$ok)
    expect_null(res$message)
  })

  it("denies a privileged command from a non-member", {
    local_mocked_bindings(
      gt_actor_is_authorized = function(source, actor, ...) FALSE
    )
    res <- cmd_authorize(
      list(action = "invite"),
      actor = "stranger",
      source = "slack",
      workspace = "organiser"
    )
    expect_false(res$ok)
    expect_match(res$message, "global team")
    expect_match(res$message, "Slack username")
  })

  it("allows a privileged Slack command from the organiser workspace", {
    local_mocked_bindings(
      gt_actor_is_authorized = function(source, actor, ...) TRUE
    )
    res <- cmd_authorize(
      list(action = "invite"),
      actor = "amowinckel",
      source = "slack",
      workspace = "organiser"
    )
    expect_true(res$ok)
  })

  it("denies privileged Slack commands from the community workspace", {
    called <- FALSE
    local_mocked_bindings(
      gt_actor_is_authorized = function(...) {
        called <<- TRUE
        TRUE
      }
    )
    res <- cmd_authorize(
      list(action = "invite"),
      actor = "amowinckel",
      source = "slack",
      workspace = "community"
    )
    expect_false(res$ok)
    expect_match(res$message, "organisers Slack workspace")
    expect_false(called)
  })

  it("denies privileged Slack commands when the workspace is unknown", {
    res <- cmd_authorize(
      list(action = "invite"),
      actor = "amowinckel",
      source = "slack",
      workspace = NULL
    )
    expect_false(res$ok)
    expect_match(res$message, "organisers Slack workspace")
  })

  it("ignores workspace for GitHub commands", {
    local_mocked_bindings(
      gt_actor_is_authorized = function(source, actor, ...) TRUE
    )
    res <- cmd_authorize(
      list(action = "invite"),
      actor = "ada",
      source = "github"
    )
    expect_true(res$ok)
  })

  it("fails closed with a retry message when the check errors", {
    local_mocked_bindings(
      gt_actor_is_authorized = function(source, actor, ...) {
        stop("airtable unreachable")
      }
    )
    suppressMessages(
      res <- cmd_authorize(
        list(action = "offboard"),
        actor = "ada",
        source = "github"
      )
    )
    expect_false(res$ok)
    expect_match(res$message, "verify")
  })
})
