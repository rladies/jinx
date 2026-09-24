comment_from <- function(login, body) {
  list(user = list(login = login), body = body)
}

describe("chapter_email_approval_login", {
  it("accepts a marker comment from a person", {
    expect_identical(
      chapter_email_approval_login(
        comment_from("someone", "looks good /jinx approve-email")
      ),
      "someone"
    )
  })

  it("ignores a comment without the marker", {
    expect_identical(
      chapter_email_approval_login(comment_from("someone", "looks good")),
      ""
    )
  })

  it("never lets a bot approve", {
    expect_identical(
      chapter_email_approval_login(
        comment_from("jinx[bot]", "/jinx approve-email")
      ),
      ""
    )
    expect_identical(
      chapter_email_approval_login(
        comment_from("github-actions", "/jinx approve-email")
      ),
      ""
    )
  })

  it("survives a comment with no body or author", {
    expect_identical(chapter_email_approval_login(list()), "")
  })
})

describe("chapter_email_approver_is_member", {
  it("accepts a confirmed active member", {
    local_mocked_bindings(
      gh = function(...) list(state = "active"),
      .package = "gh"
    )
    expect_true(chapter_email_approver_is_member("someone", "rladies"))
  })

  it("rejects a pending invitation", {
    local_mocked_bindings(
      gh = function(...) list(state = "pending"),
      .package = "gh"
    )
    expect_false(chapter_email_approver_is_member("someone", "rladies"))
  })

  it("fails closed when the membership API cannot be reached", {
    local_mocked_bindings(
      gh = function(...) stop("503 Service Unavailable"),
      .package = "gh"
    )
    expect_false(chapter_email_approver_is_member("someone", "rladies"))
  })

  it("accepts membership of any approving team", {
    local_mocked_bindings(
      gh = function(endpoint, ...) {
        args <- list(...)
        if (identical(args$team, "global")) {
          return(list(state = "active"))
        }
        stop("404")
      },
      .package = "gh"
    )
    expect_true(chapter_email_approver_is_member("someone", "rladies"))
  })
})

describe("chapter_email_approvals", {
  it("returns each distinct human approver once", {
    local_mocked_bindings(
      gh = function(...) {
        list(
          comment_from("alice", "/jinx approve-email"),
          comment_from("alice", "/jinx approve-email again"),
          comment_from("bob", "no marker here"),
          comment_from("jinx[bot]", "/jinx approve-email")
        )
      },
      .package = "gh"
    )
    local_mocked_bindings(chapter_email_approver_is_member = function(...) TRUE)
    expect_identical(chapter_email_approvals(5), "alice")
  })

  it("ignores an approval from someone outside the approving teams", {
    local_mocked_bindings(
      gh = function(...) {
        list(
          comment_from("outsider", "/jinx approve-email"),
          comment_from("alice", "/jinx approve-email")
        )
      },
      .package = "gh"
    )
    local_mocked_bindings(
      chapter_email_approver_is_member = function(login, ...) login == "alice"
    )
    expect_message(approvers <- chapter_email_approvals(5))
    expect_identical(approvers, "alice")
  })

  it("ignores every approval when membership cannot be confirmed", {
    local_mocked_bindings(
      gh = function(endpoint, ...) {
        if (grepl("comments", endpoint)) {
          return(list(comment_from("alice", "/jinx approve-email")))
        }
        stop("503 Service Unavailable")
      },
      .package = "gh"
    )
    expect_message(approvers <- chapter_email_approvals(5))
    expect_length(approvers, 0)
  })

  it("is empty when nobody has approved", {
    local_mocked_bindings(
      gh = function(...) list(comment_from("bob", "just a comment")),
      .package = "gh"
    )
    local_mocked_bindings(chapter_email_approver_is_member = function(...) TRUE)
    expect_length(chapter_email_approvals(5), 0)
  })
})

describe("chapter_email_provision", {
  it("refuses when the issue carries no chapter block", {
    local_mocked_bindings(chapter_meta_fetch = function(...) NULL)
    expect_error(chapter_email_provision(5), "does not say which chapter")
  })

  it("refuses when nobody has approved, without calling the worker", {
    called <- FALSE
    local_mocked_bindings(
      chapter_meta_fetch = function(...) list(city = "Oslo"),
      chapter_email_approvals = function(...) character(0),
      chapter_mailbox_create = function(...) {
        called <<- TRUE
        "oslo@rladies.org"
      }
    )
    expect_error(chapter_email_provision(5), "No approval")
    expect_false(called)
  })

  it("creates the mailbox once approved and reports who approved", {
    posted <- NULL
    ticked <- NULL
    local_mocked_bindings(
      chapter_meta_fetch = function(...) list(city = "Oslo"),
      chapter_email_approvals = function(...) c("alice", "bob"),
      chapter_mailbox_create = function(city, ...) "oslo@rladies.org",
      announce_post_reply = function(org, repo, number, body) posted <<- body,
      chapter_checklist_tick = function(number, pattern, ...) {
        ticked <<- pattern
        TRUE
      }
    )
    email <- chapter_email_provision(5)
    expect_identical(email, "oslo@rladies.org")
    expect_match(posted, "@alice, @bob", fixed = TRUE)
    expect_match(ticked, "create the chapter email")
  })

  it("passes the city from the issue to the worker", {
    seen <- NULL
    local_mocked_bindings(
      chapter_meta_fetch = function(...) list(city = "Córdoba"),
      chapter_email_approvals = function(...) "alice",
      chapter_mailbox_create = function(city, ...) {
        seen <<- city
        "cordoba@rladies.org"
      },
      announce_post_reply = function(...) invisible(NULL),
      chapter_checklist_tick = function(...) TRUE
    )
    chapter_email_provision(5)
    expect_identical(seen, "Córdoba")
  })

  it("never records the password in the issue comment", {
    posted <- NULL
    local_mocked_bindings(
      chapter_meta_fetch = function(...) list(city = "Oslo"),
      chapter_email_approvals = function(...) "alice",
      chapter_mailbox_create = function(...) "oslo@rladies.org",
      announce_post_reply = function(org, repo, number, body) posted <<- body,
      chapter_checklist_tick = function(...) TRUE
    )
    chapter_email_provision(5)
    expect_false(grepl("password was set|password is", posted))
    expect_match(posted, "not recorded anywhere")
  })
})

describe("/jinx chapter-email parsing", {
  it("takes an issue number", {
    expect_identical(
      cmd_parse("/jinx chapter-email 12"),
      list(action = "chapter-email", issue = 12L)
    )
  })

  it("accepts the spelled-out phrasing", {
    expect_identical(cmd_parse("/jinx chapter email 12")$issue, 12L)
  })

  it("refuses a city, since provisioning needs the approved issue", {
    parsed <- cmd_parse("/jinx chapter-email Oslo")
    expect_identical(parsed$action, "error")
    expect_match(parsed$message, "issue number")
  })

  it("explains itself when given nothing", {
    expect_identical(cmd_parse("/jinx chapter-email")$action, "error")
  })
})
