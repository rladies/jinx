library(httr2)

describe("samkoma_request", {
  it("builds a request without auth when no token is given", {
    req <- samkoma_request(base_url = "https://api.example.org")
    expect_s3_class(req, "httr2_request")
    expect_false(any(grepl("Authorization", names(req$headers))))
  })

  it("attaches a bearer token when given", {
    req <- samkoma_request(
      edit_token = "secret",
      base_url = "https://api.example.org"
    )
    expect_true("Authorization" %in% names(req$headers))
  })

  it("ignores an empty token", {
    req <- samkoma_request(
      edit_token = "",
      base_url = "https://api.example.org"
    )
    expect_false(any(grepl("Authorization", names(req$headers))))
  })
})

describe("samkoma_base_url", {
  it("honours the SAMKOMA_BASE_URL env var", {
    withr::local_envvar(SAMKOMA_BASE_URL = "https://staging.example.org")
    expect_identical(samkoma_base_url(), "https://staging.example.org")
  })

  it("defaults to the production host", {
    withr::local_envvar(SAMKOMA_BASE_URL = "")
    expect_identical(samkoma_base_url(), "https://api.samkoma.org")
  })
})

describe("meeting_poll_create", {
  it("posts the poll body and returns id, url, and edit token", {
    captured <- NULL
    local_mocked_responses(function(req) {
      captured <<- req
      response_json(
        body = list(
          id = "abc123",
          url = "https://samkoma.org/p/abc123",
          editToken = "tok-xyz"
        )
      )
    })

    created <- meeting_poll_create(
      title = "Team sync",
      days = c("2026-07-01", "2026-07-02"),
      from = "09:00",
      to = "17:00",
      slot = 30,
      tz = "Europe/Oslo"
    )

    expect_identical(created$id, "abc123")
    expect_identical(created$url, "https://samkoma.org/p/abc123")
    expect_identical(created$edit_token, "tok-xyz")
    expect_match(captured$url, "/v1/polls$")
    expect_identical(captured$body$data$title, "Team sync")
    expect_identical(captured$body$data$slot, 30L)
    expect_type(captured$body$data$days, "list")
    expect_length(captured$body$data$days, 2L)
    expect_true(captured$body$data$public)
  })

  it("rejects an empty title", {
    expect_error(
      meeting_poll_create("", "2026-07-01", "09:00", "17:00", 30),
      "title"
    )
  })

  it("rejects a malformed time window", {
    expect_error(
      meeting_poll_create("X", "2026-07-01", "9am", "5pm", 30),
      "HH:MM"
    )
  })

  it("rejects a non-positive slot", {
    expect_error(
      meeting_poll_create("X", "2026-07-01", "09:00", "17:00", 0),
      "slot"
    )
  })

  it("omits the deadline field when not supplied", {
    captured <- NULL
    local_mocked_responses(function(req) {
      captured <<- req
      response_json(body = list(id = "i", url = "u", editToken = "t"))
    })
    meeting_poll_create("X", "2026-07-01", "09:00", "17:00", 30)
    expect_null(captured$body$data$deadline)
  })
})

describe("meeting_poll_best", {
  it("returns a ranked data frame with collapsed names", {
    local_mocked_responses(list(response_json(
      body = list(
        total = 4,
        results = list(
          list(
            slot = "2026-07-01T10:00",
            count = 3,
            names = list("a", "b", "c")
          ),
          list(slot = "2026-07-02T14:00", count = 1, names = list("a"))
        )
      )
    )))

    best <- meeting_poll_best("abc123")
    expect_identical(nrow(best), 2L)
    expect_identical(best$slot[1], "2026-07-01T10:00")
    expect_identical(best$count[1], 3L)
    expect_identical(best$names[1], "a, b, c")
    expect_identical(attr(best, "total"), 4L)
  })

  it("returns an empty data frame when there are no responses", {
    local_mocked_responses(list(response_json(
      body = list(
        total = 0,
        results = list()
      )
    )))
    best <- meeting_poll_best("abc123")
    expect_identical(nrow(best), 0L)
    expect_named(best, c("slot", "count", "names"))
  })
})

describe("meeting_poll_lock", {
  it("requires an edit token", {
    expect_error(
      meeting_poll_lock("abc123", "2026-07-01T10:00", edit_token = ""),
      "edit_token"
    )
  })

  it("posts the chosen slot with the token attached", {
    captured <- NULL
    local_mocked_responses(function(req) {
      captured <<- req
      response_json(body = list(ok = TRUE))
    })
    meeting_poll_lock("abc123", "2026-07-01T10:00", edit_token = "tok")
    expect_match(captured$url, "/v1/polls/abc123/lock$")
    expect_identical(captured$body$data$slot, "2026-07-01T10:00")
  })

  it("clears the lock by sending an explicit null slot", {
    captured <- NULL
    local_mocked_responses(function(req) {
      captured <<- req
      response_json(body = list(ok = TRUE))
    })
    meeting_poll_lock("abc123", NULL, edit_token = "tok")
    expect_true("slot" %in% names(captured$body$data))
    expect_null(captured$body$data$slot)
    json <- jsonlite::toJSON(
      captured$body$data,
      auto_unbox = TRUE,
      null = "null"
    )
    expect_match(json, "\"slot\":null", fixed = TRUE)
  })

  it("rejects an id that could manipulate the URL", {
    expect_error(
      meeting_poll_lock("../../admin", "x", edit_token = "tok"),
      "alphanumeric"
    )
  })
})

describe("samkoma_escape_md", {
  it("leaves plain text untouched", {
    expect_identical(samkoma_escape_md("Team sync"), "Team sync")
  })

  it("breaks markdown links so they cannot be injected", {
    out <- samkoma_escape_md("[click](https://evil.example)")
    expect_match(out, "\\[click\\]", fixed = TRUE)
    expect_false(grepl("(?<!\\\\)[][]", out, perl = TRUE))
  })

  it("entity-encodes angle brackets and ampersands", {
    out <- samkoma_escape_md("<https://evil|x> & co")
    expect_false(grepl("<", out, fixed = TRUE))
    expect_false(grepl(">", out, fixed = TRUE))
    expect_match(out, "&lt;", fixed = TRUE)
    expect_match(out, "&amp;", fixed = TRUE)
  })

  it("collapses newlines so block markdown cannot be injected", {
    out <- samkoma_escape_md("line1\n# heading\n- item")
    expect_false(grepl("\n", out, fixed = TRUE))
  })

  it("escapes the backslash before adding its own escapes", {
    expect_identical(samkoma_escape_md("a\\b"), "a\\\\b")
  })
})

describe("meeting_poll_format_created", {
  it("links the poll and hides the edit token", {
    created <- list(
      id = "abc123",
      url = "https://samkoma.org/p/abc123",
      edit_token = "tok-secret"
    )
    out <- meeting_poll_format_created(created, "Team sync")
    expect_match(out, "Team sync", fixed = TRUE)
    expect_match(out, "https://samkoma.org/p/abc123", fixed = TRUE)
    expect_false(grepl("tok-secret", out, fixed = TRUE))
  })

  it("neutralises markdown injection in the title", {
    created <- list(id = "abc123", url = "https://samkoma.org/p/abc123")
    out <- meeting_poll_format_created(
      created,
      "[gotcha](https://evil.example)"
    )
    expect_false(grepl("(?<!\\\\)[][]", out, perl = TRUE))
    expect_match(out, "https://samkoma.org/p/abc123", fixed = TRUE)
  })
})

describe("meeting_poll_format_best", {
  it("lists the top slots", {
    best <- data.frame(
      slot = c("2026-07-01T10:00", "2026-07-02T14:00"),
      count = c(3L, 1L),
      names = c("a, b, c", "a"),
      stringsAsFactors = FALSE
    )
    out <- meeting_poll_format_best(best, title = "Team sync", top = 1)
    expect_match(out, "Best meeting times: Team sync", fixed = TRUE)
    expect_match(out, "2026-07-01T10:00", fixed = TRUE)
    expect_false(grepl("2026-07-02T14:00", out, fixed = TRUE))
  })

  it("shows the count out of total respondents when total is known", {
    best <- data.frame(
      slot = "2026-07-01T10:00",
      count = 3L,
      names = "a, b, c",
      stringsAsFactors = FALSE
    )
    attr(best, "total") <- 5L
    out <- meeting_poll_format_best(best)
    expect_match(out, "3/5 available", fixed = TRUE)
  })

  it("omits the total when it is unknown", {
    best <- data.frame(
      slot = "2026-07-01T10:00",
      count = 3L,
      names = "",
      stringsAsFactors = FALSE
    )
    out <- meeting_poll_format_best(best)
    expect_match(out, "3 available", fixed = TRUE)
    expect_false(grepl("/", out, fixed = TRUE))
  })

  it("handles no availability", {
    out <- meeting_poll_format_best(meeting_poll_best_empty())
    expect_match(out, "No availability", fixed = TRUE)
  })

  it("neutralises markdown injection in participant names and title", {
    best <- data.frame(
      slot = "2026-07-01T10:00",
      count = 1L,
      names = "[click](https://evil.example)",
      stringsAsFactors = FALSE
    )
    out <- meeting_poll_format_best(
      best,
      title = "<https://evil|pwn>"
    )
    expect_false(grepl("(?<!\\\\)[][]", out, perl = TRUE))
    expect_false(grepl("<https", out, fixed = TRUE))
  })
})

describe("meeting_poll_get", {
  it("fetches the poll and returns the parsed object", {
    captured <- NULL
    local_mocked_responses(function(req) {
      captured <<- req
      response_json(body = list(id = "abc123", title = "Team sync"))
    })
    poll <- meeting_poll_get("abc123")
    expect_identical(poll$title, "Team sync")
    expect_match(captured$url, "/v1/polls/abc123$")
  })

  it("sends the edit token when given", {
    captured <- NULL
    local_mocked_responses(function(req) {
      captured <<- req
      response_json(body = list(id = "abc123"))
    })
    meeting_poll_get("abc123", edit_token = "tok")
    expect_true("Authorization" %in% names(captured$headers))
  })

  it("rejects an id that could manipulate the URL", {
    expect_error(meeting_poll_get("a/b"), "alphanumeric")
    expect_error(meeting_poll_get("a b?x=1"), "alphanumeric")
  })
})

describe("meeting_poll_ics", {
  it("returns the raw .ics body", {
    captured <- NULL
    local_mocked_responses(function(req) {
      captured <<- req
      response(
        headers = list("Content-Type" = "text/calendar"),
        body = charToRaw("BEGIN:VCALENDAR\nEND:VCALENDAR")
      )
    })
    ics <- meeting_poll_ics("abc123")
    expect_match(ics, "BEGIN:VCALENDAR", fixed = TRUE)
    expect_match(captured$url, "/v1/polls/abc123/ics$")
  })

  it("rejects a non-alphanumeric id", {
    expect_error(meeting_poll_ics("../secret"), "alphanumeric")
  })
})

describe("samkoma_perform error handling", {
  it("surfaces the API error detail for a 4xx", {
    local_mocked_responses(list(response_json(
      status = 400,
      body = list(error = "invalid timezone")
    )))
    expect_error(
      meeting_poll_create("X", "2026-07-01", "09:00", "17:00", 30),
      "invalid timezone"
    )
  })

  it("gives a rate-limit message on 429", {
    local_mocked_responses(list(response_json(
      status = 429,
      body = list(error = "rate_limited")
    )))
    expect_error(
      meeting_poll_create("X", "2026-07-01", "09:00", "17:00", 30),
      "rate limit"
    )
  })
})
