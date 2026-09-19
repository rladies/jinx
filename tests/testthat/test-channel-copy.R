copy_fixture <- function() {
  path <- withr::local_tempfile(fileext = ".csv", .local_envir = parent.frame())
  utils::write.csv(
    data.frame(
      workspace = c("community", "community", "community", "organiser"),
      channel = c("general", "jobs", "ghost", "blog"),
      flagged = "0",
      is_new_channel = c("0", "0", "0", "0"),
      members = "10",
      topic_now = c("general talk room", "", "", "old topic"),
      topic_new = c(
        "General chat",
        "Job postings",
        "Nothing here",
        "New topic"
      ),
      topic_action = "edit",
      description_now = c("", "post jobs", "", ""),
      description_new = c(
        "General conversation.",
        "Post job openings.",
        "x",
        ""
      ),
      description_action = "edit",
      note = "",
      stringsAsFactors = FALSE
    ),
    path,
    row.names = FALSE
  )
  path
}

rename_fixture <- function() {
  path <- withr::local_tempfile(fileext = ".csv", .local_envir = parent.frame())
  utils::write.csv(
    data.frame(
      workspace = c("community", "community"),
      tier = "t",
      old = c("events_global", "already_done"),
      new = c("events-global", "already-done"),
      why = "separator",
      stringsAsFactors = FALSE
    ),
    path,
    row.names = FALSE
  )
  path
}

fake_index <- function() {
  data.frame(
    id = c("C1", "C2", "C3", "C4"),
    name = c("general", "jobs", "events_global", "already-done"),
    topic = c("general talk room", "", "Events", ""),
    purpose = c("", "a different purpose", "", ""),
    is_member = c(TRUE, FALSE, FALSE, TRUE),
    stringsAsFactors = FALSE
  )
}

fixture_plan <- function(workspace) {
  channel_copy_plan(
    workspace,
    index = fake_index(),
    proposals = channel_copy_proposals(workspace, path = copy_fixture()),
    renames = channel_rename_proposals(workspace, path = rename_fixture())
  )
}

describe("channel_copy_proposals", {
  it("returns only the requested workspace", {
    props <- channel_copy_proposals("community", path = copy_fixture())
    expect_setequal(props$workspace, "community")
    expect_setequal(props$channel, c("general", "jobs", "ghost"))
  })

  it("ships proposals for both workspaces", {
    expect_gt(nrow(channel_copy_proposals("community")), 0)
    expect_gt(nrow(channel_copy_proposals("organiser")), 0)
  })

  it("rejects an unknown workspace", {
    expect_error(channel_copy_proposals("nope"), "should be one of")
  })
})

describe("channel_rename_proposals", {
  it("returns only the requested workspace", {
    renames <- channel_rename_proposals("community", path = rename_fixture())
    expect_setequal(renames$old, c("events_global", "already_done"))
  })
})

describe("slack_channel_index", {
  it("shapes the channel list into the frame the plan compares against", {
    index <- slack_channel_index(
      "community",
      channels = list(
        list(
          id = "C1",
          name = "a",
          topic = list(value = "t"),
          purpose = list(value = "p"),
          is_member = TRUE
        ),
        list(id = "C2", name = "b")
      )
    )
    expect_equal(index$id, c("C1", "C2"))
    expect_equal(index$name, c("a", "b"))
    expect_equal(index$topic, c("t", ""))
    expect_equal(index$purpose, c("p", ""))
    expect_equal(index$is_member, c(TRUE, FALSE))
  })

  it("delegates paging to slack_conversations_list", {
    asked <- NULL
    local_mocked_bindings(
      slack_conversations_list = function(team_id, workspace, ...) {
        asked <<- workspace
        list(list(id = "C9", name = "z"))
      }
    )
    index <- slack_channel_index("organiser")
    expect_equal(asked, "organiser")
    expect_equal(index$id, "C9")
  })
})

describe("channel_copy_plan", {
  it("plans an edit when Slack still holds the recorded value", {
    plan <- fixture_plan("community")
    row <- plan[plan$channel == "general" & plan$field == "topic", ]
    expect_equal(row$status, "apply")
    expect_equal(row$to, "General chat")
    expect_equal(row$method, "conversations.setTopic")
  })

  it("marks a value Slack already holds as unchanged", {
    index <- fake_index()
    index$topic[index$name == "general"] <- "General chat"
    plan <- channel_copy_plan(
      "community",
      index = index,
      proposals = channel_copy_proposals("community", path = copy_fixture()),
      renames = channel_rename_proposals("community", path = rename_fixture())
    )
    row <- plan[plan$channel == "general" & plan$field == "topic", ]
    expect_equal(row$status, "unchanged")
  })

  it("marks a value edited since the review as drift", {
    plan <- fixture_plan("community")
    row <- plan[plan$channel == "jobs" & plan$field == "description", ]
    expect_equal(row$status, "drift")
  })

  it("marks an absent channel as missing", {
    plan <- fixture_plan("community")
    expect_equal(plan$status[plan$channel == "ghost"], "missing")
  })

  it("marks an empty proposal as unchanged rather than blanking Slack", {
    plan <- fixture_plan("organiser")
    expect_false(any(plan$to == "" & plan$status == "apply"))
  })

  it("treats an already-renamed channel as unchanged, not missing", {
    plan <- fixture_plan("community")
    row <- plan[plan$field == "name" & plan$from == "already_done", ]
    expect_equal(row$status, "unchanged")
  })

  it("plans a rename for a channel still under its old name", {
    plan <- fixture_plan("community")
    row <- plan[plan$field == "name" & plan$from == "events_global", ]
    expect_equal(row$status, "apply")
    expect_equal(row$to, "events-global")
    expect_equal(row$method, "conversations.rename")
  })
})

describe("channel_copy_apply", {
  it("sends nothing on a dry run", {
    called <- FALSE
    local_mocked_bindings(
      slack_api_call = function(...) {
        called <<- TRUE
        list(ok = TRUE)
      }
    )
    plan <- data.frame(
      channel = "general",
      id = "C1",
      field = "topic",
      method = "conversations.setTopic",
      from = "old",
      to = "new",
      status = "apply",
      is_member = TRUE,
      stringsAsFactors = FALSE
    )
    expect_message(
      out <- channel_copy_apply(plan, "xoxb-test", dry_run = TRUE),
      "1 change would be sent"
    )
    expect_false(called)
    expect_false(out$applied)
  })

  it("sends only rows with status apply", {
    sent <- list()
    local_mocked_bindings(
      slack_api_call = function(token, method, body = list()) {
        sent[[length(sent) + 1]] <<- list(method = method, body = body)
        list(ok = TRUE)
      }
    )
    plan <- data.frame(
      channel = c("general", "jobs"),
      id = c("C1", "C2"),
      field = c("topic", "description"),
      method = c("conversations.setTopic", "conversations.setPurpose"),
      from = c("old", "old"),
      to = c("new", "new"),
      status = c("apply", "drift"),
      is_member = TRUE,
      stringsAsFactors = FALSE
    )
    out <- suppressMessages(channel_copy_apply(
      plan,
      "xoxb-test",
      dry_run = FALSE
    ))
    expect_length(sent, 1)
    expect_equal(sent[[1]]$method, "conversations.setTopic")
    expect_equal(sent[[1]]$body$topic, "new")
    expect_equal(out$applied, c(TRUE, FALSE))
  })

  it("maps each field to the parameter Slack expects", {
    sent <- list()
    local_mocked_bindings(
      slack_api_call = function(token, method, body = list()) {
        sent[[length(sent) + 1]] <<- body
        list(ok = TRUE)
      }
    )
    plan <- data.frame(
      channel = c("a", "b", "c"),
      id = c("C1", "C2", "C3"),
      field = c("topic", "description", "name"),
      method = c(
        "conversations.setTopic",
        "conversations.setPurpose",
        "conversations.rename"
      ),
      from = "old",
      to = c("t", "p", "n"),
      status = "apply",
      is_member = TRUE,
      stringsAsFactors = FALSE
    )
    suppressMessages(channel_copy_apply(plan, "xoxb-test", dry_run = FALSE))
    expect_equal(sent[[1]]$topic, "t")
    expect_equal(sent[[2]]$purpose, "p")
    expect_equal(sent[[3]]$name, "n")
  })

  it("records a failure without aborting the rest of the pass", {
    local_mocked_bindings(
      slack_api_call = function(token, method, body = list()) {
        if (identical(body$channel, "C1")) {
          cli::cli_abort("Slack API failed: restricted_action")
        }
        list(ok = TRUE)
      }
    )
    plan <- data.frame(
      channel = c("a", "b"),
      id = c("C1", "C2"),
      field = "topic",
      method = "conversations.setTopic",
      from = "old",
      to = "new",
      status = "apply",
      is_member = TRUE,
      stringsAsFactors = FALSE
    )
    out <- suppressMessages(channel_copy_apply(
      plan,
      "xoxb-test",
      dry_run = FALSE
    ))
    expect_equal(out$applied, c(FALSE, TRUE))
    expect_match(out$error[1], "restricted_action")
    expect_true(is.na(out$error[2]))
  })

  it("joins channels the bot is not in before mutating them", {
    methods <- character()
    local_mocked_bindings(
      slack_api_call = function(token, method, body = list()) {
        methods <<- c(methods, method)
        list(ok = TRUE)
      }
    )
    plan <- data.frame(
      channel = c("a", "a", "b"),
      id = c("C1", "C1", "C2"),
      field = c("topic", "description", "topic"),
      method = c(
        "conversations.setTopic",
        "conversations.setPurpose",
        "conversations.setTopic"
      ),
      from = "old",
      to = "new",
      status = "apply",
      is_member = c(FALSE, FALSE, TRUE),
      stringsAsFactors = FALSE
    )
    suppressMessages(channel_copy_apply(plan, "xoxb-test", dry_run = FALSE))
    expect_equal(sum(methods == "conversations.join"), 1)
    expect_equal(methods[1], "conversations.join")
  })

  it("does not join when join is FALSE", {
    methods <- character()
    local_mocked_bindings(
      slack_api_call = function(token, method, body = list()) {
        methods <<- c(methods, method)
        list(ok = TRUE)
      }
    )
    plan <- data.frame(
      channel = "a",
      id = "C1",
      field = "topic",
      method = "conversations.setTopic",
      from = "old",
      to = "new",
      status = "apply",
      is_member = FALSE,
      stringsAsFactors = FALSE
    )
    suppressMessages(channel_copy_apply(
      plan,
      "xoxb-test",
      dry_run = FALSE,
      join = FALSE
    ))
    expect_false("conversations.join" %in% methods)
  })

  it("leaves skipped channels alone", {
    called <- FALSE
    local_mocked_bindings(
      slack_api_call = function(...) {
        called <<- TRUE
        list(ok = TRUE)
      }
    )
    plan <- data.frame(
      channel = "general",
      id = "C1",
      field = "topic",
      method = "conversations.setTopic",
      from = "old",
      to = "new",
      status = "apply",
      is_member = TRUE,
      stringsAsFactors = FALSE
    )
    out <- suppressMessages(
      channel_copy_apply(plan, "xoxb-test", dry_run = FALSE, skip = "general")
    )
    expect_false(called)
    expect_equal(out$status, "skipped")
  })
})
