library(httr2)

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
