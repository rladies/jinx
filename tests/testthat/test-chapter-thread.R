thread_comment <- function(body, login = "organiser") {
  list(body = body, user = list(login = login))
}

describe("chapter_thread_urlnames", {
  it("finds a group urlname in a pasted URL", {
    expect_identical(
      chapter_thread_urlnames(
        "Group is up: https://www.meetup.com/rladies-oslo/"
      ),
      "rladies-oslo"
    )
  })

  it("handles a URL with no www and no trailing slash", {
    expect_identical(
      chapter_thread_urlnames("see http://meetup.com/rladies-la-plata"),
      "rladies-la-plata"
    )
  })

  it("finds several and keeps them unique and ordered", {
    text <- paste(
      "https://www.meetup.com/rladies-oslo/ and",
      "https://www.meetup.com/rladies-bergen/ and",
      "https://www.meetup.com/rladies-oslo/ again"
    )
    expect_identical(
      chapter_thread_urlnames(text),
      c("rladies-oslo", "rladies-bergen")
    )
  })

  it("ignores reserved paths that are not groups", {
    expect_identical(
      chapter_thread_urlnames("https://www.meetup.com/pro/rladies"),
      character(0)
    )
    expect_identical(
      chapter_thread_urlnames("https://www.meetup.com/members/12345"),
      character(0)
    )
  })

  it("returns nothing for text with no Meetup link", {
    expect_identical(chapter_thread_urlnames("No link here"), character(0))
    expect_identical(chapter_thread_urlnames(""), character(0))
  })
})

describe("chapter_thread_emails", {
  it("finds a chapter mailbox", {
    expect_identical(
      chapter_thread_emails("Created oslo@rladies.org for them"),
      "oslo@rladies.org"
    )
  })

  it("lower-cases and de-duplicates", {
    expect_identical(
      chapter_thread_emails("Oslo@RLadies.org and oslo@rladies.org"),
      "oslo@rladies.org"
    )
  })

  it("ignores addresses at other domains", {
    expect_identical(
      chapter_thread_emails("reach me at someone@gmail.com"),
      character(0)
    )
  })
})

describe("chapter_thread_is_human", {
  it("accepts a person", {
    expect_true(chapter_thread_is_human(thread_comment("hi", "organiser")))
  })

  it("rejects jinx and other bots", {
    expect_false(chapter_thread_is_human(thread_comment("hi", "jinx[bot]")))
    expect_false(chapter_thread_is_human(thread_comment(
      "hi",
      "github-actions"
    )))
  })

  it("rejects an entry with no author", {
    expect_false(chapter_thread_is_human(list(body = "hi")))
  })
})

describe("chapter_thread_counts", {
  it("counts a human comment", {
    expect_true(chapter_thread_counts(thread_comment("hi", "organiser")))
  })

  it("counts jinx's record of a group it published", {
    entry <- thread_comment(
      paste(
        "Live at https://www.meetup.com/rladies-oslo/",
        chapter_thread_live_marker()
      ),
      "jinx[bot]"
    )
    expect_true(chapter_thread_counts(entry))
  })

  it("does not count jinx's proposed urlname", {
    expect_false(chapter_thread_counts(thread_comment(
      "Proposed: x",
      "jinx[bot]"
    )))
  })
})

describe("chapter_thread_scan", {
  local_thread <- function(comments, env = parent.frame()) {
    local_mocked_bindings(
      gh = function(endpoint, ...) comments,
      .package = "gh",
      .env = env
    )
  }

  it("reads the urlname and mailbox out of the conversation", {
    local_thread(list(
      thread_comment("Mailbox is oslo@rladies.org", "email-team"),
      thread_comment(
        "Group: https://www.meetup.com/rladies-oslo/",
        "meetup-team"
      )
    ))
    found <- chapter_thread_scan(7)
    expect_identical(found$urlname, "rladies-oslo")
    expect_identical(found$email, "oslo@rladies.org")
    expect_identical(found$meetup_url, "https://www.meetup.com/rladies-oslo/")
  })

  it("ignores jinx's own proposed urlname", {
    local_thread(list(
      thread_comment(
        "Proposed urlname: https://www.meetup.com/rladies-guess/",
        "jinx[bot]"
      ),
      thread_comment(
        "Live at https://www.meetup.com/rladies-real/",
        "meetup-team"
      )
    ))
    expect_identical(chapter_thread_scan(7)$urlname, "rladies-real")
  })

  it("keeps the first human posting when a later comment quotes it", {
    local_thread(list(
      thread_comment(
        "Live at https://www.meetup.com/rladies-oslo/",
        "meetup-team"
      ),
      thread_comment("Thanks! https://www.meetup.com/rladies-typo/", "someone")
    ))
    expect_identical(chapter_thread_scan(7)$urlname, "rladies-oslo")
  })

  it("reads the urlname from jinx's own publish record", {
    local_thread(list(
      thread_comment(
        "Proposed: https://www.meetup.com/rladies-guess/",
        "jinx[bot]"
      ),
      thread_comment(
        paste(
          "Published at https://www.meetup.com/rladies-real/",
          chapter_thread_live_marker()
        ),
        "jinx[bot]"
      )
    ))
    expect_identical(chapter_thread_scan(7)$urlname, "rladies-real")
  })

  it("returns nothing when the thread carries neither fact yet", {
    local_thread(list(thread_comment("Working on it", "organiser")))
    found <- chapter_thread_scan(7)
    expect_null(found$urlname)
    expect_null(found$email)
    expect_null(found$meetup_url)
  })

  it("survives an empty thread", {
    local_thread(list())
    expect_null(chapter_thread_scan(7)$urlname)
  })
})
