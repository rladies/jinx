library(httr2)

describe("rag_chunk_id", {
  it("returns 32-character hex string", {
    id <- rag_chunk_id("rladies/jinx", "/x", 0L)
    expect_match(id, "^[0-9a-f]{32}$")
  })

  it("matches the JS sha256-slice-32 scheme", {
    expect_identical(
      rag_chunk_id("rladies/rladiesguide", "/getting-started/", 0L),
      "1e94883243882ca25577366a0981fcc3"
    )
  })

  it("varies with chunk_idx", {
    expect_false(
      rag_chunk_id("r/x", "/p", 0L) == rag_chunk_id("r/x", "/p", 1L)
    )
  })
})

describe("cloudflare_embed", {
  it("returns one numeric vector per input text", {
    body <- list(
      success = TRUE,
      result = list(data = list(c(0.1, 0.2), c(0.3, 0.4)))
    )
    local_mocked_responses(list(response_json(body = body)))
    vecs <- cloudflare_embed(
      c("hello", "world"),
      account_id = "acc123",
      api_token = "tok"
    )
    expect_length(vecs, 2L)
    expect_identical(vecs[[1]], c(0.1, 0.2))
  })

  it("surfaces a classed cloudflarer_error on API failure", {
    body <- list(
      success = FALSE,
      errors = list(list(code = 1000, message = "bad thing")),
      result = NULL
    )
    local_mocked_responses(list(response_json(status_code = 400, body = body)))
    expect_error(
      cloudflare_embed("hello", account_id = "acc123", api_token = "tok"),
      class = "cloudflarer_error"
    )
  })
})

describe("cloudflare_account_id", {
  it("returns the sole account ID when token has exactly one", {
    body <- list(success = TRUE, result = list(list(id = "acc123")))
    local_mocked_responses(list(response_json(body = body)))
    expect_identical(cloudflare_account_id("tok"), "acc123")
  })

  it("aborts when token has multiple accounts", {
    body <- list(success = TRUE, result = list(list(id = "a"), list(id = "b")))
    local_mocked_responses(list(response_json(body = body)))
    expect_error(cloudflare_account_id("tok"), "explicitly")
  })

  it("aborts when token has zero accounts", {
    body <- list(success = TRUE, result = list())
    local_mocked_responses(list(response_json(body = body)))
    expect_error(cloudflare_account_id("tok"), "no accessible")
  })
})
