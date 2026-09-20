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
