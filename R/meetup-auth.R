#' Meetup's GraphQL endpoint
#'
#' `api.meetup.com/gql` returns 404 as of 2026-09; `gql-ext` is the
#' endpoint that answers.
#'
#' @return The endpoint URL.
#' @keywords internal
#' @noRd
meetup_graphql_url <- function() "https://api.meetup.com/gql-ext"

#' Build the signed assertion for Meetup's JWT flow
#'
#' Meetup's server-to-server flow signs a short-lived RS256 JWT with the
#' OAuth client's private key and exchanges it for an access token. The
#' claim shape is Meetup's, not a convention: `sub` is the authorised
#' member id (the client owner), `iss` is the client key, `aud` is
#' literally `api.meetup.com`, and the header carries the signing key id
#' as `kid`.
#'
#' @param client_key OAuth client key (the `iss` claim).
#' @param member_id Authorised member id (the `sub` claim).
#' @param signing_key_id Signing key id (the `kid` header).
#' @param private_key An `openssl` key, or a path to a PEM file.
#' @param now Current time, for testing.
#' @param lifetime_seconds How long the assertion is valid.
#' @return The signed assertion.
#' @keywords internal
#' @noRd
meetup_jwt_assertion <- function(
  client_key,
  member_id,
  signing_key_id,
  private_key,
  now = Sys.time(),
  lifetime_seconds = 120
) {
  key <- if (inherits(private_key, "key")) {
    private_key
  } else {
    openssl::read_key(private_key)
  }

  header <- list(kid = signing_key_id, typ = "JWT", alg = "RS256")
  claims <- list(
    sub = member_id,
    iss = client_key,
    aud = "api.meetup.com",
    exp = as.integer(as.numeric(now)) + lifetime_seconds
  )

  encode <- function(x) {
    base64_url_encode(charToRaw(
      as.character(jsonlite::toJSON(x, auto_unbox = TRUE))
    ))
  }
  signing_input <- paste0(encode(header), ".", encode(claims))

  signature <- openssl::signature_create(
    charToRaw(signing_input),
    openssl::sha256,
    key
  )
  paste0(signing_input, ".", base64_url_encode(signature))
}

#' Exchange a signed assertion for a Meetup access token
#'
#' @inheritParams meetup_jwt_assertion
#' @return The access token.
#' @keywords internal
#' @noRd
meetup_access_token <- function(
  client_key = Sys.getenv("MEETUP_CLIENT_KEY"),
  member_id = Sys.getenv("MEETUP_MEMBER_ID"),
  signing_key_id = Sys.getenv("MEETUP_SIGNING_KEY_ID"),
  private_key = Sys.getenv("MEETUP_PRIVATE_KEY")
) {
  supplied <- list(
    MEETUP_CLIENT_KEY = client_key,
    MEETUP_MEMBER_ID = member_id,
    MEETUP_SIGNING_KEY_ID = signing_key_id,
    MEETUP_PRIVATE_KEY = private_key
  )
  missing <- names(supplied)[!nzchar(unlist(supplied))]
  if (length(missing) > 0) {
    cli::cli_abort("Meetup credentials are not configured: {missing}")
  }

  assertion <- meetup_jwt_assertion(
    client_key,
    member_id,
    signing_key_id,
    private_key
  )

  resp <- httr2::request("https://secure.meetup.com") |>
    httr2::req_url_path_append("oauth2", "access") |>
    httr2::req_body_form(
      grant_type = "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion = assertion
    ) |>
    httr2::req_perform() |>
    httr2::resp_body_json()

  token <- resp$access_token
  if (is.null(token)) {
    cli::cli_abort("Meetup token exchange returned no access token")
  }
  token
}

#' Run a GraphQL query against Meetup
#'
#' @param query GraphQL query or mutation.
#' @param variables Named list of variables, or `NULL`.
#' @param token Access token. Obtained via the JWT flow by default.
#' @return The parsed `data` field.
#' @keywords internal
#' @noRd
meetup_graphql <- function(query, variables = NULL, token = NULL) {
  token <- token %or% meetup_access_token()
  body <- list(query = query)
  if (!is.null(variables)) {
    body$variables <- variables
  }

  resp <- httr2::request(meetup_graphql_url()) |>
    httr2::req_auth_bearer_token(token) |>
    httr2::req_body_json(body) |>
    httr2::req_retry(max_tries = 3) |>
    httr2::req_perform() |>
    httr2::resp_body_json()

  if (length(resp$errors %or% list()) > 0) {
    messages <- vapply(
      resp$errors,
      function(e) e$message %or% "unknown error",
      character(1)
    )
    cli::cli_abort(c(
      "Meetup rejected the query.",
      "x" = paste(messages, collapse = "; ")
    ))
  }
  resp$data
}
