library(httr2)

describe("chapter_mailbox_create", {
  it("refuses to run without an API key", {
    expect_error(
      chapter_mailbox_create("Oslo", api_key = ""),
      "JINX_WORKER_API_KEY is not set"
    )
  })

  it("returns the address the worker created", {
    local_mocked_responses(list(
      response_json(status_code = 201, body = list(email = "oslo@rladies.org"))
    ))
    expect_message(
      email <- chapter_mailbox_create("Oslo", api_key = "k")
    )
    expect_identical(email, "oslo@rladies.org")
  })

  it("surfaces the worker's refusal rather than a bare status", {
    local_mocked_responses(list(
      response_json(
        status_code = 400,
        body = list(error = "admin is a reserved address")
      )
    ))
    expect_error(
      chapter_mailbox_create("admin", api_key = "k"),
      "reserved address"
    )
  })

  it("reports a conflict when the mailbox already exists", {
    local_mocked_responses(list(
      response_json(
        status_code = 409,
        body = list(error = "oslo@rladies.org already exists")
      )
    ))
    expect_error(
      chapter_mailbox_create("Oslo", api_key = "k"),
      "already exists"
    )
  })

  it("falls back to the status code when the body carries no message", {
    local_mocked_responses(list(response_json(
      status_code = 502,
      body = list()
    )))
    expect_error(chapter_mailbox_create("Oslo", api_key = "k"), "502")
  })
})

describe("worker_api_key", {
  it("prefers the current variable name", {
    withr::with_envvar(
      c(JINX_WORKER_API_KEY = "new", JINX_API_KEY = "old"),
      expect_identical(worker_api_key(), "new")
    )
  })

  it("still honours the old name during the rename", {
    withr::with_envvar(
      c(JINX_WORKER_API_KEY = "", JINX_API_KEY = "old"),
      expect_identical(worker_api_key(), "old")
    )
  })

  it("is empty when neither is set", {
    withr::with_envvar(
      c(JINX_WORKER_API_KEY = "", JINX_API_KEY = ""),
      expect_identical(worker_api_key(), "")
    )
  })
})
