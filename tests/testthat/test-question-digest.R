describe("question_content_gaps", {
  it("keeps only no_match/low_confidence outcomes and folds duplicates", {
    rows <- data.frame(
      question = c(
        "How do I get a swag budget?",
        "how do i get a swag budget?",
        "review my code",
        "what is a chapter?",
        "why can't I log in?"
      ),
      outcome = c(
        "no_match",
        "no_match",
        "coding_declined",
        "answered",
        "low_confidence"
      ),
      stringsAsFactors = FALSE
    )
    gaps <- question_content_gaps(rows)
    expect_equal(nrow(gaps), 2L)
    expect_false(any(gaps$outcome == "coding_declined"))
    expect_false(any(gaps$outcome == "answered"))
    expect_equal(
      gaps$count[gaps$question == "How do I get a swag budget?"],
      2L
    )
  })

  it("honours min_count", {
    rows <- data.frame(
      question = c("a", "b"),
      outcome = c("no_match", "low_confidence"),
      stringsAsFactors = FALSE
    )
    gaps <- question_content_gaps(rows, min_count = 2)
    expect_equal(nrow(gaps), 0L)
  })

  it("returns an empty data frame for NULL input", {
    expect_equal(nrow(question_content_gaps(NULL)), 0L)
  })
})

describe("question_coding_declined_count", {
  it("counts only coding_declined rows", {
    rows <- data.frame(
      outcome = c("coding_declined", "coding_declined", "answered", "no_match"),
      stringsAsFactors = FALSE
    )
    expect_identical(question_coding_declined_count(rows), 2L)
  })

  it("returns 0 for NULL or empty input", {
    expect_identical(question_coding_declined_count(NULL), 0L)
    expect_identical(question_coding_declined_count(data.frame()), 0L)
  })
})

describe("question_draft_guide_snippet", {
  it("returns the trimmed draft on success", {
    local_mocked_bindings(
      cloudflare_generate = function(...) "  A short draft.  "
    )
    expect_identical(
      question_draft_guide_snippet("why?", account_id = "a", api_token = "t"),
      "A short draft."
    )
  })

  it("returns NULL when the model responds with nothing usable", {
    local_mocked_bindings(
      cloudflare_generate = function(...) "   "
    )
    expect_null(
      question_draft_guide_snippet("why?", account_id = "a", api_token = "t")
    )
  })

  it("returns NULL and warns when the model call errors", {
    local_mocked_bindings(
      cloudflare_generate = function(...) cli::cli_abort("boom")
    )
    expect_warning(
      result <- question_draft_guide_snippet(
        "why?",
        account_id = "a",
        api_token = "t"
      ),
      "draft_guide_snippet failed"
    )
    expect_null(result)
  })
})

describe("question_digest_format", {
  it("renders drafted gaps, undrafted gaps, downvotes, and the coding FYI", {
    gaps <- data.frame(
      question = c(
        "How do I get a swag budget?",
        "How do I resign as organiser?"
      ),
      outcome = c("no_match", "low_confidence"),
      count = c(2L, 1L),
      stringsAsFactors = FALSE
    )
    drafts <- gaps[1, , drop = FALSE]
    drafts$draft <- "Ask in #organisers-chat."
    downvoted <- data.frame(
      question = "how do I start a chapter?",
      up = 1L,
      down = 3L,
      stringsAsFactors = FALSE
    )
    md <- question_digest_format(
      days = 7,
      total = 12,
      gaps = gaps,
      drafts = drafts,
      downvoted = downvoted,
      coding_count = 2L
    )
    expect_match(md, "last 7 days", fixed = TRUE)
    expect_match(md, "12 questions logged", fixed = TRUE)
    expect_match(md, "How do I get a swag budget?", fixed = TRUE)
    expect_match(md, "asked", fixed = TRUE)
    expect_match(md, "Ask in #organisers-chat.", fixed = TRUE)
    expect_match(md, "How do I resign as organiser?", fixed = TRUE)
    expect_match(md, "how do I start a chapter?", fixed = TRUE)
    expect_match(md, "declined 2 coding questions", fixed = TRUE)
  })

  it("escapes Slack mrkdwn control characters in question text and drafts", {
    gaps <- data.frame(
      question = "See <https://evil.example|this link> & <!channel> for info",
      outcome = "no_match",
      count = 1L,
      stringsAsFactors = FALSE
    )
    drafts <- gaps
    drafts$draft <- "Click <https://evil.example|here> & read [more](javascript:1)"
    md <- question_digest_format(
      days = 7,
      total = 1,
      gaps = gaps,
      drafts = drafts,
      downvoted = data.frame(),
      coding_count = 0L
    )
    expect_false(grepl("<https://evil.example|this link>", md, fixed = TRUE))
    expect_false(grepl("<!channel>", md, fixed = TRUE))
    expect_false(grepl("<https://evil.example|here>", md, fixed = TRUE))
    expect_match(md, "&lt;https://evil.example|this link&gt;", fixed = TRUE)
    expect_match(md, "&amp; &lt;!channel&gt;", fixed = TRUE)
  })

  it("shows a placeholder when a gap has no draft", {
    gaps <- data.frame(
      question = "why won't jinx answer?",
      outcome = "no_match",
      count = 1L,
      stringsAsFactors = FALSE
    )
    drafts <- gaps
    drafts$draft <- NA_character_
    md <- question_digest_format(
      days = 7,
      total = 1,
      gaps = gaps,
      drafts = drafts,
      downvoted = data.frame(),
      coding_count = 0L
    )
    expect_match(md, "couldn't draft one", fixed = TRUE)
  })

  it("reports none this week when there are no gaps", {
    empty <- data.frame(
      question = character(),
      outcome = character(),
      count = integer()
    )
    md <- question_digest_format(
      days = 7,
      total = 3,
      gaps = empty,
      drafts = empty,
      downvoted = data.frame(),
      coding_count = 0L
    )
    expect_match(md, "none this week", fixed = TRUE)
  })

  it("uses singular day/question wording when the count is 1", {
    empty <- data.frame(
      question = character(),
      outcome = character(),
      count = integer()
    )
    md <- question_digest_format(
      days = 1,
      total = 1,
      gaps = empty,
      drafts = empty,
      downvoted = data.frame(),
      coding_count = 1L
    )
    expect_match(md, "last 1 day*", fixed = TRUE)
    expect_match(md, "1 question logged", fixed = TRUE)
    expect_match(md, "declined 1 coding question", fixed = TRUE)
  })
})

describe("question_digest_build", {
  it("returns NULL when nothing was logged", {
    local_mocked_bindings(
      question_log_query = function(...) data.frame()
    )
    expect_null(
      question_digest_build(days = 7, account_id = "a", api_token = "t")
    )
  })

  it("builds a digest from logged rows, drafting the top gaps", {
    rows <- data.frame(
      question = c(
        "How do I get a swag budget?",
        "review my code",
        "what is a chapter?"
      ),
      outcome = c("no_match", "coding_declined", "answered"),
      up = c(0L, 0L, 0L),
      down = c(0L, 0L, 0L),
      stringsAsFactors = FALSE
    )
    local_mocked_bindings(
      question_log_query = function(...) rows,
      question_draft_guide_snippet = function(question, ...) {
        paste("Draft for", question)
      }
    )
    text <- question_digest_build(days = 7, account_id = "a", api_token = "t")
    expect_match(text, "3 questions logged", fixed = TRUE)
    expect_match(text, "How do I get a swag budget?", fixed = TRUE)
    expect_match(text, "Draft for How do I get a swag budget?", fixed = TRUE)
    expect_match(text, "declined 1 coding question", fixed = TRUE)
  })
})

describe("question_digest_post", {
  it("posts the digest text and returns TRUE when there's something to report", {
    posted <- list()
    local_mocked_bindings(
      question_digest_build = function(...) "the digest text",
      slack_post_message = function(text, channel, token) {
        posted[["text"]] <<- text
        posted[["channel"]] <<- channel
        list(ok = TRUE)
      }
    )
    result <- question_digest_post(
      days = 7,
      channel = "team-jinx",
      slack_token = "tok"
    )
    expect_true(result)
    expect_identical(posted$text, "the digest text")
    expect_identical(posted$channel, "team-jinx")
  })

  it("returns FALSE and does not post when there's nothing to report", {
    called <- FALSE
    local_mocked_bindings(
      question_digest_build = function(...) NULL,
      slack_post_message = function(...) {
        called <<- TRUE
        list(ok = TRUE)
      }
    )
    result <- question_digest_post(days = 7)
    expect_false(result)
    expect_false(called)
  })

  it("aborts when the Slack post fails, instead of silently succeeding", {
    local_mocked_bindings(
      question_digest_build = function(...) "the digest text",
      slack_post_message = function(...) {
        list(ok = FALSE, error = "channel_not_found")
      }
    )
    expect_error(
      question_digest_post(days = 7),
      "channel_not_found"
    )
  })
})
