relay_comment <- function(
  body = "/jinx chapter-status 7",
  association = "MEMBER",
  login = "organiser",
  created_at = "2026-10-04T12:00:00Z",
  issue_url = "https://api.github.com/repos/rladies/new-chapters-onboarding/issues/7"
) {
  list(
    body = body,
    author_association = association,
    user = list(login = login),
    created_at = created_at,
    issue_url = issue_url
  )
}

local_relay_comment <- function(comment, env = parent.frame()) {
  local_mocked_bindings(
    gh = function(endpoint, ...) comment,
    .package = "gh",
    .env = env
  )
}

relay_now <- as.POSIXct(
  "2026-10-04T12:01:00",
  format = "%Y-%m-%dT%H:%M:%S",
  tz = "UTC"
)

describe("cmd_relay_split_repo", {
  it("splits an owner/repo reference", {
    expect_identical(
      cmd_relay_split_repo("rladies/new-chapters-onboarding"),
      c("rladies", "new-chapters-onboarding")
    )
  })

  it("rejects anything that is not owner/repo", {
    expect_error(cmd_relay_split_repo("jinx"), "owner/repo")
    expect_error(cmd_relay_split_repo("rladies/"), "owner/repo")
    expect_error(cmd_relay_split_repo(""), "owner/repo")
    expect_error(cmd_relay_split_repo(NULL), "owner/repo")
  })
})

describe("cmd_relay_resolve", {
  it("reads the command text and author off the comment", {
    local_relay_comment(relay_comment())
    relayed <- cmd_relay_resolve(
      "rladies/new-chapters-onboarding",
      1,
      now = relay_now
    )
    expect_identical(relayed$text, "/jinx chapter-status 7")
    expect_identical(relayed$actor, "organiser")
    expect_identical(relayed$issue, 7L)
    expect_identical(relayed$owner, "rladies")
    expect_identical(relayed$name, "new-chapters-onboarding")
  })

  it("ignores leading whitespace around the command", {
    local_relay_comment(relay_comment(body = "  /jinx chapter-status 7\n"))
    relayed <- cmd_relay_resolve("rladies/x", 1, now = relay_now)
    expect_identical(relayed$text, "/jinx chapter-status 7")
  })

  it("refuses a comment that is not a command", {
    local_relay_comment(relay_comment(body = "Thanks, looks good!"))
    expect_error(
      cmd_relay_resolve("rladies/x", 1, now = relay_now),
      "not a command"
    )
  })

  it("refuses an author who is not a member", {
    local_relay_comment(relay_comment(association = "NONE"))
    expect_error(
      cmd_relay_resolve("rladies/x", 1, now = relay_now),
      "not from a member"
    )
  })

  it("accepts owners and collaborators", {
    for (association in c("OWNER", "COLLABORATOR")) {
      local_relay_comment(relay_comment(association = association))
      expect_identical(
        cmd_relay_resolve("rladies/x", 1, now = relay_now)$actor,
        "organiser"
      )
    }
  })

  it("refuses a replayed comment older than the window", {
    local_relay_comment(relay_comment())
    expect_error(
      cmd_relay_resolve(
        "rladies/x",
        1,
        now = relay_now + 3600
      ),
      "too old"
    )
  })

  it("refuses a comment with an unreadable timestamp", {
    local_relay_comment(relay_comment(created_at = "not a date"))
    expect_error(cmd_relay_resolve("rladies/x", 1, now = relay_now), "too old")
  })

  it("refuses a comment with no issue number", {
    local_relay_comment(relay_comment(issue_url = ""))
    expect_error(
      cmd_relay_resolve("rladies/x", 1, now = relay_now),
      "issue number"
    )
  })

  it("never trusts a relayed actor over the API's", {
    local_relay_comment(relay_comment(login = "real-member"))
    relayed <- cmd_relay_resolve("rladies/x", 1, now = relay_now)
    expect_identical(relayed$actor, "real-member")
  })
})
