library(httr2)

describe("reaction_direction", {
  it("maps thumbs and common positives/negatives", {
    expect_identical(reaction_direction("thumbsup"), "up")
    expect_identical(reaction_direction("+1"), "up")
    expect_identical(reaction_direction("heart"), "up")
    expect_identical(reaction_direction("thumbsdown"), "down")
    expect_identical(reaction_direction("-1"), "down")
  })

  it("strips skin-tone modifiers before matching", {
    expect_identical(reaction_direction("thumbsup::skin-tone-3"), "up")
  })

  it("returns NULL for neutral reactions", {
    expect_null(reaction_direction("eyes"))
    expect_null(reaction_direction(""))
    expect_null(reaction_direction(NA))
  })
})

describe("reaction_log_increment", {
  it("increments the daily counter for a workspace/reaction pair", {
    responses <- list(
      response_json(body = list(count = 2L, last_at = "2026-07-01T00:00:00Z")),
      response_json(body = list(success = TRUE))
    )
    local_mocked_responses(responses)
    count <- reaction_log_increment(
      "T_ORG",
      "thumbsup",
      namespace_id = "ns1",
      account_id = "acc123",
      api_token = "tok"
    )
    expect_identical(count, 3L)
  })

  it("starts at 1 when there is no prior count", {
    local_mocked_responses(list(
      response(status_code = 404, body = charToRaw("")),
      response_json(body = list(success = TRUE))
    ))
    count <- reaction_log_increment(
      "T_ORG",
      "thumbsup",
      namespace_id = "ns1",
      account_id = "acc123",
      api_token = "tok"
    )
    expect_identical(count, 1L)
  })
})

describe("question_vote_apply", {
  it("increments up on a positive reaction to a linked answer", {
    local_mocked_responses(list(
      response(body = charToRaw("1")),
      response_json(
        body = list(
          success = TRUE,
          result = list(list(
            success = TRUE,
            meta = list(),
            results = list()
          ))
        )
      )
    ))
    applied <- question_vote_apply(
      "T_ORG",
      item = list(type = "message", channel = "C1", ts = "1.5"),
      reaction = "thumbsup",
      namespace_id = "ns1",
      account_id = "acc123",
      database_id = "db1",
      api_token = "tok"
    )
    expect_true(applied)
  })

  it("ignores reactions on non-message items", {
    applied <- question_vote_apply(
      "T_ORG",
      item = list(type = "file", channel = "C1", ts = "1.5"),
      reaction = "thumbsup"
    )
    expect_false(applied)
  })

  it("ignores neutral reactions", {
    applied <- question_vote_apply(
      "T_ORG",
      item = list(type = "message", channel = "C1", ts = "1.5"),
      reaction = "eyes"
    )
    expect_false(applied)
  })

  it("ignores reactions with no linked answer", {
    local_mocked_responses(list(response(
      status_code = 404,
      body = charToRaw("")
    )))
    applied <- question_vote_apply(
      "T_ORG",
      item = list(type = "message", channel = "C1", ts = "9.9"),
      reaction = "thumbsup",
      namespace_id = "ns1",
      account_id = "acc123",
      api_token = "tok"
    )
    expect_false(applied)
  })

  it("returns FALSE and warns instead of throwing when the D1 update fails", {
    local_mocked_responses(list(
      response(body = charToRaw("1")),
      response_json(status_code = 500, body = list(success = FALSE))
    ))
    expect_warning(
      applied <- question_vote_apply(
        "T_ORG",
        item = list(type = "message", channel = "C1", ts = "1.5"),
        reaction = "thumbsup",
        namespace_id = "ns1",
        account_id = "acc123",
        database_id = "db1",
        api_token = "tok"
      ),
      "question_log vote failed"
    )
    expect_false(applied)
  })
})

describe("reaction_event_apply", {
  it("calls both the tally and the vote apply", {
    tally_args <- NULL
    vote_args <- NULL
    local_mocked_bindings(
      reaction_log_increment = function(team_id, reaction, ...) {
        tally_args <<- list(team_id = team_id, reaction = reaction)
        1L
      },
      question_vote_apply = function(team_id, item, reaction, ...) {
        vote_args <<- list(team_id = team_id, item = item, reaction = reaction)
        TRUE
      }
    )
    reaction_event_apply(
      "T_ORG",
      list(
        reaction = "thumbsup",
        item = list(type = "message", channel = "C1", ts = "1.0")
      )
    )
    expect_identical(tally_args$team_id, "T_ORG")
    expect_identical(tally_args$reaction, "thumbsup")
    expect_identical(vote_args$reaction, "thumbsup")
  })

  it("still applies the vote when the tally increment fails", {
    vote_called <- FALSE
    local_mocked_bindings(
      reaction_log_increment = function(...) stop("KV put unavailable"),
      question_vote_apply = function(...) {
        vote_called <<- TRUE
        TRUE
      }
    )
    expect_warning(
      reaction_event_apply(
        "T_ORG",
        list(
          reaction = "thumbsup",
          item = list(type = "message", channel = "C1", ts = "1.0")
        )
      ),
      "reaction_log write failed"
    )
    expect_true(vote_called)
  })

  it("still applies the tally when the vote apply fails", {
    tally_called <- FALSE
    local_mocked_bindings(
      reaction_log_increment = function(...) {
        tally_called <<- TRUE
        1L
      },
      question_vote_apply = function(...) stop("D1 unavailable")
    )
    expect_warning(
      reaction_event_apply(
        "T_ORG",
        list(
          reaction = "thumbsup",
          item = list(type = "message", channel = "C1", ts = "1.0")
        )
      ),
      "question_vote failed"
    )
    expect_true(tally_called)
  })
})

describe("question_gaps_rank", {
  it("keeps only gap outcomes and folds near-duplicates by count", {
    rows <- data.frame(
      question = c(
        "How do I get a swag budget?",
        "how do i get a swag budget?",
        "review my code",
        "what is a chapter?"
      ),
      outcome = c("no_match", "no_match", "coding_declined", "answered"),
      stringsAsFactors = FALSE
    )
    gaps <- question_gaps_rank(rows)
    expect_equal(nrow(gaps), 2L)
    expect_equal(gaps$count[[1]], 2L)
    expect_false(any(gaps$outcome == "answered"))
  })

  it("returns an empty data frame when there are no gap outcomes", {
    rows <- data.frame(
      question = "what is a chapter?",
      outcome = "answered",
      stringsAsFactors = FALSE
    )
    expect_equal(nrow(question_gaps_rank(rows)), 0L)
  })

  it("respects the limit argument", {
    rows <- data.frame(
      question = c("a", "b", "c"),
      outcome = rep("no_match", 3),
      stringsAsFactors = FALSE
    )
    expect_equal(nrow(question_gaps_rank(rows, limit = 2)), 2L)
  })
})

describe("question_downvoted_rank", {
  it("surfaces answers with net-negative reactions, worst first", {
    rows <- data.frame(
      question = c("a", "b", "c"),
      outcome = rep("answered", 3),
      up = c(0L, 2L, 1L),
      down = c(3L, 2L, 2L),
      stringsAsFactors = FALSE
    )
    out <- question_downvoted_rank(rows)
    expect_equal(out$question, c("a", "c"))
  })

  it("returns no rows when nothing is net-downvoted", {
    rows <- data.frame(
      question = "a",
      up = 2L,
      down = 1L,
      stringsAsFactors = FALSE
    )
    expect_equal(nrow(question_downvoted_rank(rows)), 0L)
  })
})

describe("question_log_query", {
  it("returns the D1 result rows as a data frame", {
    body <- list(
      success = TRUE,
      result = list(list(
        success = TRUE,
        meta = list(),
        results = list(
          list(
            id = 1,
            day = "2026-07-01",
            question = "recent",
            outcome = "answered",
            top_score = 0.82,
            sources = "guide",
            up = 1,
            down = 0
          )
        )
      ))
    )
    local_mocked_responses(list(response_json(body = body)))
    rows <- question_log_query(
      since_day = "2026-06-01",
      account_id = "acc123",
      database_id = "db1",
      api_token = "tok"
    )
    expect_equal(nrow(rows), 1L)
    expect_equal(rows$question, "recent")
  })
})

describe("parse_questions_command", {
  it("defaults to 7 days", {
    cmd <- cmd_parse("/jinx questions")
    expect_identical(cmd$action, "questions")
    expect_identical(cmd$days, 7L)
  })

  it("parses an explicit day count", {
    cmd <- cmd_parse("/jinx questions 14")
    expect_identical(cmd$action, "questions")
    expect_identical(cmd$days, 14L)
  })

  it("errors on a non-numeric day count", {
    cmd <- cmd_parse("/jinx questions soon")
    expect_identical(cmd$action, "error")
  })

  it("errors on a non-positive day count", {
    cmd <- cmd_parse("/jinx questions 0")
    expect_identical(cmd$action, "error")
  })

  it("normalizes the 'question log' phrase", {
    cmd <- cmd_parse("/jinx question log 14")
    expect_identical(cmd$action, "questions")
    expect_identical(cmd$days, 14L)
  })
})

describe("question_log_format", {
  it("reports no questions logged when rows is empty", {
    md <- question_log_format(
      data.frame(),
      data.frame(),
      data.frame(),
      days = 7
    )
    expect_match(md, "No questions logged")
  })

  it("renders outcome, gap, and downvote sections", {
    rows <- data.frame(
      outcome = c("answered", "no_match"),
      stringsAsFactors = FALSE
    )
    gaps <- data.frame(
      question = "what is a chapter?",
      outcome = "no_match",
      count = 2L,
      stringsAsFactors = FALSE
    )
    downvoted <- data.frame(
      question = "how do I start?",
      up = 0L,
      down = 3L,
      stringsAsFactors = FALSE
    )
    md <- question_log_format(rows, gaps, downvoted, days = 7)
    expect_match(md, "Total questions.*2")
    expect_match(md, "what is a chapter?", fixed = TRUE)
    expect_match(md, "how do I start?", fixed = TRUE)
  })
})
