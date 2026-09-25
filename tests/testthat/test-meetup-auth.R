library(httr2)

test_key <- function() openssl::rsa_keygen(2048)

decode_part <- function(assertion, i) {
  part <- strsplit(assertion, ".", fixed = TRUE)[[1]][[i]]
  padded <- paste0(part, strrep("=", (4 - nchar(part) %% 4) %% 4))
  padded <- chartr("-_", "+/", padded)
  jsonlite::fromJSON(rawToChar(jsonlite::base64_dec(padded)))
}

describe("meetup_jwt_assertion", {
  key <- test_key()

  it("has three base64url segments and no padding", {
    assertion <- meetup_jwt_assertion("ck", "123", "kid1", key)
    parts <- strsplit(assertion, ".", fixed = TRUE)[[1]]
    expect_length(parts, 3)
    expect_false(grepl("[+/=]", assertion))
  })

  it("carries the header Meetup's flow requires", {
    header <- decode_part(meetup_jwt_assertion("ck", "123", "kid1", key), 1)
    expect_identical(header$alg, "RS256")
    expect_identical(header$typ, "JWT")
    expect_identical(header$kid, "kid1")
  })

  it("carries Meetup's claim shape, not a generic one", {
    claims <- decode_part(meetup_jwt_assertion("ck", "123", "kid1", key), 2)
    expect_identical(claims$iss, "ck")
    expect_identical(claims$sub, "123")
    expect_identical(claims$aud, "api.meetup.com")
  })

  it("expires shortly after it is issued", {
    now <- as.POSIXct("2026-01-01 00:00:00", tz = "UTC")
    claims <- decode_part(
      meetup_jwt_assertion("ck", "123", "kid1", key, now = now),
      2
    )
    expect_equal(claims$exp, as.integer(as.numeric(now)) + 120)
  })

  it("is signed by the private key it was given", {
    assertion <- meetup_jwt_assertion("ck", "123", "kid1", key)
    parts <- strsplit(assertion, ".", fixed = TRUE)[[1]]
    signing_input <- paste0(parts[[1]], ".", parts[[2]])
    sig64 <- chartr("-_", "+/", parts[[3]])
    sig64 <- paste0(sig64, strrep("=", (4 - nchar(sig64) %% 4) %% 4))
    expect_true(openssl::signature_verify(
      charToRaw(signing_input),
      jsonlite::base64_dec(sig64),
      openssl::sha256,
      as.list(key)$pubkey
    ))
  })

  it("accepts a PEM path as well as a key object", {
    path <- withr::local_tempfile(fileext = ".pem")
    openssl::write_pem(key, path)
    expect_type(meetup_jwt_assertion("ck", "123", "kid1", path), "character")
  })
})

describe("meetup_access_token", {
  it("names every missing credential rather than failing at the API", {
    withr::with_envvar(
      c(
        MEETUP_CLIENT_KEY = "",
        MEETUP_MEMBER_ID = "",
        MEETUP_SIGNING_KEY_ID = "",
        MEETUP_PRIVATE_KEY = ""
      ),
      expect_error(meetup_access_token(), "MEETUP_CLIENT_KEY")
    )
  })

  it("returns the access token from the exchange", {
    key <- test_key()
    path <- withr::local_tempfile(fileext = ".pem")
    openssl::write_pem(key, path)
    local_mocked_responses(list(response_json(
      body = list(access_token = "at")
    )))
    expect_identical(
      meetup_access_token("ck", "123", "kid1", path),
      "at"
    )
  })

  it("errors when the exchange returns no token", {
    key <- test_key()
    path <- withr::local_tempfile(fileext = ".pem")
    openssl::write_pem(key, path)
    local_mocked_responses(list(response_json(body = list(error = "bad"))))
    expect_error(
      meetup_access_token("ck", "123", "kid1", path),
      "no access token"
    )
  })
})

describe("meetup_graphql", {
  it("returns the data field on success", {
    local_mocked_responses(list(
      response_json(body = list(data = list(groupByUrlname = list(id = "1"))))
    ))
    result <- meetup_graphql("{ groupByUrlname { id } }", token = "t")
    expect_identical(result$groupByUrlname$id, "1")
  })

  it("surfaces GraphQL errors rather than returning empty data", {
    local_mocked_responses(list(
      response_json(body = list(errors = list(list(message = "no such field"))))
    ))
    expect_error(
      meetup_graphql("{ nope }", token = "t"),
      "no such field"
    )
  })

  it("posts to the gql-ext endpoint, not the retired gql one", {
    expect_identical(meetup_graphql_url(), "https://api.meetup.com/gql-ext")
  })
})
