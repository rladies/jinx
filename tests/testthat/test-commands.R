describe("parse_command", {
  it("returns NULL for non-jinx comments", {
    expect_null(parse_command("Hello world"))
    expect_null(parse_command("Some random comment"))
    expect_null(parse_command("/notjinx help"))
  })

  it("parses help command", {
    cmd <- parse_command("/jinx help")
    expect_equal(cmd$action, "help")
  })

  it("parses invite command", {
    cmd <- parse_command("/jinx invite @octocat to website")
    expect_equal(cmd$action, "invite")
    expect_equal(cmd$username, "octocat")
    expect_equal(cmd$team, "website")
  })

  it("strips @ from username in invite", {
    cmd <- parse_command("/jinx invite @octocat to blog")
    expect_equal(cmd$username, "octocat")
  })

  it("handles username without @ in invite", {
    cmd <- parse_command("/jinx invite octocat to blog")
    expect_equal(cmd$username, "octocat")
  })

  it("returns error for malformed invite", {
    cmd <- parse_command("/jinx invite @octocat")
    expect_equal(cmd$action, "error")
    expect_true(grepl("Usage", cmd$message))
  })

  it("parses offboard command", {
    cmd <- parse_command("/jinx offboard @octocat from website")
    expect_equal(cmd$action, "offboard")
    expect_equal(cmd$username, "octocat")
    expect_equal(cmd$team, "website")
  })

  it("returns error for malformed offboard", {
    cmd <- parse_command("/jinx offboard @octocat")
    expect_equal(cmd$action, "error")
    expect_true(grepl("Usage", cmd$message))
  })

  it("parses report command with type", {
    cmd <- parse_command("/jinx report weekly")
    expect_equal(cmd$action, "report")
    expect_equal(cmd$type, "weekly")

    cmd <- parse_command("/jinx report monthly")
    expect_equal(cmd$type, "monthly")
  })

  it("defaults report type to weekly", {
    cmd <- parse_command("/jinx report")
    expect_equal(cmd$action, "report")
    expect_equal(cmd$type, "weekly")
  })

  it("returns error for invalid report type", {
    cmd <- parse_command("/jinx report yearly")
    expect_equal(cmd$action, "error")
  })

  it("parses remind command", {
    cmd <- parse_command("/jinx remind")
    expect_equal(cmd$action, "remind")
  })

  it("returns unknown for unrecognized commands", {
    cmd <- parse_command("/jinx foobar baz")
    expect_equal(cmd$action, "unknown")
    expect_true(grepl("foobar", cmd$raw))
  })

  it("handles leading/trailing whitespace", {
    cmd <- parse_command("  /jinx help  ")
    expect_equal(cmd$action, "help")
  })

  it("is case-insensitive for action", {
    cmd <- parse_command("/jinx HELP")
    expect_equal(cmd$action, "help")

    cmd <- parse_command("/jinx Invite @user to website")
    expect_equal(cmd$action, "invite")
  })
})
