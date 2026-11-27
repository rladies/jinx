describe("rag_request_proxied()", {
  it("fetches directly when no proxy is configured", {
    req <- rag_request_proxied(
      "https://drmowinckels.io/index.xml",
      proxy = "",
      key = "k"
    )
    expect_equal(req$url, "https://drmowinckels.io/index.xml")
    expect_null(req$body)
  })

  it("fetches directly when the proxy has no key", {
    req <- rag_request_proxied(
      "https://drmowinckels.io/index.xml",
      proxy = "https://jinx.rladies.workers.dev/content/fetch",
      key = ""
    )
    expect_equal(req$url, "https://drmowinckels.io/index.xml")
  })

  it("posts the target to the worker when both are set", {
    req <- rag_request_proxied(
      "https://drmowinckels.io/index.xml",
      proxy = "https://jinx.rladies.workers.dev/content/fetch",
      key = "secret"
    )
    expect_equal(req$url, "https://jinx.rladies.workers.dev/content/fetch")
    expect_equal(req$body$data$url, "https://drmowinckels.io/index.xml")
  })

  it("authorises the worker call with the bearer key", {
    req <- rag_request_proxied(
      "https://drmowinckels.io/index.xml",
      proxy = "https://jinx.rladies.workers.dev/content/fetch",
      key = "secret"
    )
    headers <- httr2::req_get_headers(req, "reveal")
    expect_equal(headers$Authorization, "Bearer secret")
  })
})

describe("rag_proxy_url()", {
  it("is empty when the worker URL is unset", {
    withr::local_envvar(JINX_WORKER_URL = "")
    expect_equal(rag_proxy_url(), "")
  })

  it("appends the fetch route to the worker URL", {
    withr::local_envvar(JINX_WORKER_URL = "https://jinx.rladies.workers.dev")
    expect_equal(
      rag_proxy_url(),
      "https://jinx.rladies.workers.dev/content/fetch"
    )
  })

  it("does not double the separator on a trailing slash", {
    withr::local_envvar(JINX_WORKER_URL = "https://jinx.rladies.workers.dev/")
    expect_equal(
      rag_proxy_url(),
      "https://jinx.rladies.workers.dev/content/fetch"
    )
  })
})
