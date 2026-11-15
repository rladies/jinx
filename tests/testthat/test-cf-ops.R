library(httr2)

describe("cf_ops_format_workers_report", {
  it("renders a markdown table of invocation metrics", {
    df <- data.frame(
      date = c("2026-07-01", "2026-07-02"),
      script = c("jinx", "jinx"),
      requests = c(100L, 120L),
      errors = c(1L, 0L),
      subrequests = c(50L, 60L),
      cpu_p50_us = c(12.5, 13.1),
      cpu_p99_us = c(80.0, 82.2),
      stringsAsFactors = FALSE
    )
    md <- cf_ops_format_workers_report(df)
    expect_match(md, "2026-07-01", fixed = TRUE)
    expect_match(md, "100", fixed = TRUE)
  })

  it("reports no data available for an empty data frame", {
    md <- cf_ops_format_workers_report(data.frame())
    expect_match(md, "No Workers invocation data available")
  })
})

describe("cf_ops_purge_cache", {
  it("aborts when neither files nor prefixes are supplied", {
    expect_error(
      cf_ops_purge_cache(zone_id = "zone1", token = "tok"),
      "Nothing to purge"
    )
  })

  it("never sends purge_everything in the request body", {
    captured <- NULL
    local_mocked_bindings(
      req_perform = function(req) {
        captured <<- req
        httr2::response_json(
          body = list(success = TRUE, result = list(id = "purge1"))
        )
      },
      .package = "httr2"
    )
    cf_ops_purge_cache(
      zone_id = "zone1",
      prefixes = "rladies.org/blog",
      token = "tok"
    )
    expect_false("purge_everything" %in% names(captured$body$data))
    expect_identical(captured$body$data$prefixes, "rladies.org/blog")
  })
})

describe("cf_ops_list_kv_keys", {
  it("returns the KV key listing as a data frame", {
    body <- list(
      success = TRUE,
      result = list(list(name = "greeting", expiration = NA)),
      result_info = list(cursor = "", list_complete = TRUE)
    )
    local_mocked_responses(list(response_json(body = body)))
    keys <- cf_ops_list_kv_keys(
      account_id = "acc123",
      namespace_id = "ns1",
      token = "tok"
    )
    expect_equal(keys$name, "greeting")
  })
})

describe("cf_ops_get_kv_value", {
  it("returns the raw stored value as text", {
    local_mocked_responses(list(response(body = charToRaw("hello world"))))
    value <- cf_ops_get_kv_value(
      account_id = "acc123",
      namespace_id = "ns1",
      key_name = "greeting",
      token = "tok"
    )
    expect_identical(value, "hello world")
  })
})

describe("cf_ops_kv_put", {
  it("writes a value without erroring on success", {
    local_mocked_responses(list(response_json(body = list(success = TRUE))))
    expect_no_error(
      cf_ops_kv_put(
        account_id = "acc123",
        namespace_id = "ns1",
        key_name = "greeting",
        value = "hello",
        ttl_seconds = 3600,
        token = "tok"
      )
    )
  })

  it("surfaces a classed cloudflarer_error on API failure", {
    body <- list(
      success = FALSE,
      errors = list(list(code = 1000, message = "bad thing"))
    )
    local_mocked_responses(list(response_json(status_code = 400, body = body)))
    expect_error(
      cf_ops_kv_put(
        account_id = "acc123",
        namespace_id = "ns1",
        key_name = "greeting",
        value = "hello",
        token = "tok"
      ),
      class = "cloudflarer_error"
    )
  })
})

describe("cf_ops_kv_delete", {
  it("deletes a value without erroring on success", {
    local_mocked_responses(list(response_json(body = list(success = TRUE))))
    expect_no_error(
      cf_ops_kv_delete(
        account_id = "acc123",
        namespace_id = "ns1",
        key_name = "greeting",
        token = "tok"
      )
    )
  })
})

describe("parse_cache_purge_command", {
  it("parses one or more domain-like prefixes", {
    cmd <- cmd_parse("/jinx cache-purge rladies.org/blog")
    expect_identical(cmd$action, "cache-purge")
    expect_identical(cmd$prefixes, "rladies.org/blog")
  })

  it("parses multiple prefixes", {
    cmd <- cmd_parse("/jinx cache-purge rladies.org/blog rladies.org/events")
    expect_identical(cmd$prefixes, c("rladies.org/blog", "rladies.org/events"))
  })

  it("errors when no prefix is given", {
    cmd <- cmd_parse("/jinx cache-purge")
    expect_identical(cmd$action, "error")
  })

  it("errors when a prefix doesn't look like a domain", {
    cmd <- cmd_parse("/jinx cache-purge not-a-domain")
    expect_identical(cmd$action, "error")
  })

  it("normalizes the 'purge cache' phrase", {
    cmd <- cmd_parse("/jinx purge cache rladies.org/blog")
    expect_identical(cmd$action, "cache-purge")
  })
})

describe("cf_ops_transient", {
  it("retries a transport failure, which carries no status", {
    cnd <- tryCatch(transport_error(), error = function(e) e)
    expect_true(cf_ops_transient(cnd))
  })

  it("retries a 429 or a 5xx", {
    expect_true(cf_ops_transient(list(status_code = 429L)))
    expect_true(cf_ops_transient(list(status_code = 503L)))
  })

  it("gives up on a status only the caller can fix", {
    expect_false(cf_ops_transient(list(status_code = 404L)))
    expect_false(cf_ops_transient(list(status_code = 403L)))
  })

  it("gives up on a failure raised before the request went out", {
    expect_false(cf_ops_transient(simpleError("must be a character string")))
  })

  it("gives up rather than error on a status it cannot compare", {
    expect_false(cf_ops_transient(list(status_code = NA_integer_)))
    expect_false(cf_ops_transient(list(status_code = integer())))
  })
})

describe("cf_ops_retry", {
  local_waits <- function(env = parent.frame()) {
    waits <- integer()
    local_mocked_bindings(
      cf_ops_backoff = function(attempt) waits <<- c(waits, attempt),
      .env = env
    )
    function() waits
  }

  it("returns the first successful result without waiting", {
    waits <- local_waits()
    expect_identical(cf_ops_retry(function() "value"), "value")
    expect_length(waits(), 0L)
  })

  it("tries again after a transient failure, waiting longer each time", {
    waits <- local_waits()
    attempts <- 0L
    result <- cf_ops_retry(function() {
      attempts <<- attempts + 1L
      if (attempts < 3L) {
        transport_error()
      }
      "value"
    })
    expect_identical(result, "value")
    expect_equal(attempts, 3L)
    expect_identical(waits(), c(1L, 2L))
  })

  it("re-raises once the tries run out", {
    local_waits()
    attempts <- 0L
    expect_error(
      cf_ops_retry(function() {
        attempts <<- attempts + 1L
        transport_error()
      }),
      "Failed to perform HTTP request"
    )
    expect_equal(attempts, 3L)
  })

  it("does not retry, or wait, for a failure retrying cannot fix", {
    waits <- local_waits()
    for (status in c(404L, 403L)) {
      attempts <- 0L
      expect_error(
        cf_ops_retry(function() {
          attempts <<- attempts + 1L
          cf_error(status)
        }),
        class = "cloudflarer_error"
      )
      expect_equal(attempts, 1L)
    }
    expect_length(waits(), 0L)
  })

  it("always makes the call, however small the retry budget", {
    local_waits()
    for (tries in c(1L, 0L)) {
      attempts <- 0L
      expect_error(
        cf_ops_retry(
          function() {
            attempts <<- attempts + 1L
            transport_error()
          },
          tries = tries
        ),
        "Failed to perform HTTP request"
      )
      expect_equal(attempts, 1L)
    }
  })
})

describe("the KV wrappers' retries", {
  read_greeting <- function() {
    cf_ops_get_kv_value(
      account_id = "acc123",
      namespace_id = "ns1",
      key_name = "greeting",
      token = "tok"
    )
  }

  it("carries cf_ops_get_kv_value() through a 5xx", {
    local_mocked_bindings(cf_ops_backoff = function(attempt) NULL)
    local_mocked_responses(list(
      response_json(status_code = 503, body = list(success = FALSE)),
      response(body = charToRaw("hello world"))
    ))
    expect_identical(read_greeting(), "hello world")
  })

  it("carries cf_ops_kv_put() through the 429 a per-key write limit gives", {
    local_mocked_bindings(cf_ops_backoff = function(attempt) NULL)
    local_mocked_responses(list(
      response_json(status_code = 429, body = list(success = FALSE)),
      response_json(body = list(success = TRUE))
    ))
    expect_no_error(
      cf_ops_kv_put(
        account_id = "acc123",
        namespace_id = "ns1",
        key_name = "greeting",
        value = "hello",
        token = "tok"
      )
    )
  })

  it("does not retry a key that is simply missing", {
    local_mocked_bindings(
      cf_ops_backoff = function(attempt) cli::cli_abort("should not wait")
    )
    local_mocked_responses(list(
      response_json(
        status_code = 404,
        body = list(
          success = FALSE,
          errors = list(list(code = 10009, message = "key not found"))
        )
      ),
      response(body = charToRaw("hello world"))
    ))
    expect_error(read_greeting(), class = "cloudflarer_error")
  })
})

describe("kv_string_set_load", {
  it("parses a stored JSON array", {
    local_mocked_bindings(cf_ops_get_kv_value = function(...) '["a","b"]')
    expect_identical(kv_string_set_load("k"), c("a", "b"))
  })

  it("treats an unset or unparseable key as nothing recorded", {
    local_mocked_bindings(cf_ops_get_kv_value = function(...) "")
    expect_identical(kv_string_set_load("k"), character())

    local_mocked_bindings(cf_ops_get_kv_value = function(...) "{not json")
    expect_identical(kv_string_set_load("k"), character())

    local_mocked_bindings(cf_ops_get_kv_value = function(...) cf_error(404L))
    expect_identical(kv_string_set_load("k"), character())
  })

  it("aborts rather than report an unreadable key as empty", {
    local_mocked_bindings(
      cf_ops_get_kv_value = function(...) cli::cli_abort("Couldn't connect")
    )
    expect_error(kv_string_set_load("k"), "Couldn't connect")

    local_mocked_bindings(cf_ops_get_kv_value = function(...) cf_error(500L))
    expect_error(kv_string_set_load("k"), class = "cloudflarer_error")
  })
})

describe("kv_string_set_save", {
  it("stores the values as a JSON array under the key", {
    captured <- NULL
    local_mocked_bindings(
      cf_ops_kv_put = function(..., key_name, value) {
        captured <<- list(key = key_name, value = value)
      }
    )
    kv_string_set_save("my_key", c("a", "b"))
    expect_identical(captured$key, "my_key")
    expect_identical(
      as.character(jsonlite::fromJSON(captured$value)),
      c("a", "b")
    )
  })

  it("keeps every value when no limit is given", {
    captured <- NULL
    local_mocked_bindings(
      cf_ops_kv_put = function(..., value) captured <<- value
    )
    kv_string_set_save("k", c("a", "a", "b"))
    expect_length(as.character(jsonlite::fromJSON(captured)), 3L)
  })

  it("drops duplicates and keeps the most recent when limited", {
    captured <- NULL
    local_mocked_bindings(
      cf_ops_kv_put = function(..., value) captured <<- value
    )
    kv_string_set_save("k", c("old", "dup", "dup", "new"), keep = 2L)
    expect_identical(
      as.character(jsonlite::fromJSON(captured)),
      c("dup", "new")
    )
  })
})
