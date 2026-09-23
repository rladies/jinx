library(httr2)

describe("mail_header_check", {
  it("refuses a value carrying a line break", {
    expect_error(mail_header_check("Oslo\r\nBcc: x@y.z", "subject"), "refused")
    expect_error(mail_header_check("a\nb", "to"), "refused")
  })

  it("passes an ordinary value through unchanged", {
    expect_identical(
      mail_header_check("Oslo, Norway", "subject"),
      "Oslo, Norway"
    )
  })
})

describe("mail_header_encode", {
  it("leaves an ascii subject alone", {
    expect_identical(mail_header_encode("Oslo chapter"), "Oslo chapter")
  })

  it("encodes an accented subject as an RFC 2047 word", {
    encoded <- mail_header_encode("Córdoba chapter")
    expect_match(encoded, "^=\\?UTF-8\\?B\\?")
    expect_match(encoded, "\\?=$")
  })

  it("round-trips through base64 back to the original text", {
    encoded <- mail_header_encode("Córdoba")
    payload <- sub("^=\\?UTF-8\\?B\\?", "", sub("\\?=$", "", encoded))
    decoded <- rawToChar(jsonlite::base64_dec(payload))
    Encoding(decoded) <- "UTF-8"
    expect_identical(decoded, "Córdoba")
  })
})

describe("base64_url_encode", {
  it("uses the url alphabet and drops padding", {
    encoded <- base64_url_encode(charToRaw(strrep("\xfb\xff", 4)))
    expect_false(grepl("[+/=]", encoded))
  })

  it("does not wrap long input across lines", {
    expect_false(grepl(
      "[\r\n]",
      base64_url_encode(charToRaw(strrep("a", 500)))
    ))
  })
})

describe("mail_message_build", {
  msg <- function(...) {
    mail_message_build(
      to = "someone@example.com",
      subject = "Welcome",
      body = "Hello there",
      from = "jinx@rladies.org",
      ...
    )
  }

  it("puts the headers before a blank line and then the body", {
    built <- msg(cc = NULL)
    expect_match(built, "^From: jinx@rladies.org\r\n")
    expect_match(built, "\r\n\r\nHello there$")
  })

  it("includes a Cc header only when there is one", {
    expect_match(msg(cc = "chapters@rladies.org"), "Cc: chapters@rladies.org")
    expect_false(grepl("Cc:", msg(cc = NULL)))
  })

  it("declares UTF-8", {
    expect_match(msg(cc = NULL), "charset=UTF-8", fixed = TRUE)
  })

  it("joins multiple recipients with commas", {
    built <- mail_message_build(
      to = c("a@x.com", "b@x.com"),
      subject = "s",
      body = "b",
      from = "jinx@rladies.org"
    )
    expect_match(built, "To: a@x.com, b@x.com", fixed = TRUE)
  })

  it("refuses an injected header in any field", {
    expect_error(
      mail_message_build(
        "a@x.com",
        "s\r\nBcc: evil@x.com",
        "b",
        NULL,
        "j@x.com"
      ),
      "refused"
    )
    expect_error(
      mail_message_build(
        "a@x.com\r\nBcc: evil@x.com",
        "s",
        "b",
        NULL,
        "j@x.com"
      ),
      "refused"
    )
    expect_error(
      mail_message_build(
        "a@x.com",
        "s",
        "b",
        "c@x.com\r\nBcc: e@x.com",
        "j@x.com"
      ),
      "refused"
    )
  })
})

describe("mail_access_token", {
  it("names the missing credential rather than failing at the API", {
    withr::with_envvar(
      c(
        GOOGLE_CLIENT_ID = "",
        GOOGLE_CLIENT_SECRET = "",
        GMAIL_REFRESH_TOKEN = ""
      ),
      expect_error(mail_access_token(), "not configured")
    )
  })

  it("returns the access token from the exchange", {
    withr::with_envvar(
      c(
        GOOGLE_CLIENT_ID = "id",
        GOOGLE_CLIENT_SECRET = "secret",
        GMAIL_REFRESH_TOKEN = "refresh"
      ),
      {
        local_mocked_responses(list(response_json(
          body = list(access_token = "at")
        )))
        expect_identical(mail_access_token(), "at")
      }
    )
  })

  it("errors when the exchange returns no token", {
    withr::with_envvar(
      c(
        GOOGLE_CLIENT_ID = "id",
        GOOGLE_CLIENT_SECRET = "secret",
        GMAIL_REFRESH_TOKEN = "refresh"
      ),
      {
        local_mocked_responses(list(response_json(body = list(error = "bad"))))
        expect_error(mail_access_token(), "no access token")
      }
    )
  })
})

describe("mail_send", {
  it("sends the built message and returns the id", {
    local_mocked_bindings(mail_access_token = function() "at")
    local_mocked_responses(list(response_json(body = list(id = "msg1"))))
    expect_message(id <- mail_send("a@x.com", "Welcome", "Hello"))
    expect_identical(id, "msg1")
  })

  it("ccs the onboarding inbox by default", {
    local_mocked_bindings(mail_access_token = function() "at")
    built <- mail_message_build(
      "a@x.com",
      "s",
      "b",
      cc = eval(formals(mail_send)$cc),
      from = eval(formals(mail_send)$from)
    )
    expect_match(built, "Cc: chapters@rladies.org", fixed = TRUE)
    expect_match(built, "From: jinx@rladies.org", fixed = TRUE)
  })
})
