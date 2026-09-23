#' Reject a header value that could inject extra headers
#'
#' Subjects and recipients reach this code from issue bodies and
#' workflow inputs, so a value carrying CR or LF could append headers of
#' its own - a Bcc, a different From - to the message. Anything with a
#' line break in it is refused rather than silently stripped, because a
#' city name should never contain one.
#'
#' @param value The header value.
#' @param field Field name, for the error message.
#' @return `value`, unchanged.
#' @keywords internal
#' @noRd
mail_header_check <- function(value, field) {
  if (any(grepl("[\r\n]", value))) {
    cli::cli_abort("{field} contains a line break and was refused")
  }
  value
}

#' Encode a header value that is not plain ASCII
#'
#' Chapter cities carry accents, so a subject like "Cordoba" is fine as
#' is but "Córdoba" has to go out as an RFC 2047 encoded word or it
#' arrives as mojibake.
#'
#' @param value The header value.
#' @return The value, encoded only if it needs to be.
#' @keywords internal
#' @noRd
mail_header_encode <- function(value) {
  if (!grepl("[^\x01-\x7F]", value, perl = TRUE)) {
    return(value)
  }
  encoded <- base64_url_strip(jsonlite::base64_enc(charToRaw(
    enc2utf8(value)
  )))
  paste0("=?UTF-8?B?", encoded, "?=")
}

#' Strip the newlines jsonlite's base64 encoder inserts
#' @keywords internal
#' @noRd
base64_url_strip <- function(x) {
  gsub("[\r\n]", "", x)
}

#' Base64url-encode a raw vector for the Gmail API
#' @keywords internal
#' @noRd
base64_url_encode <- function(bytes) {
  encoded <- base64_url_strip(jsonlite::base64_enc(bytes))
  encoded <- chartr("+/", "-_", encoded)
  sub("=+$", "", encoded)
}

#' Assemble an RFC 5322 message
#'
#' @param to Recipient address.
#' @param subject Message subject.
#' @param body Plain text body.
#' @param cc Cc address, or `NULL`.
#' @param from Sender address.
#' @return The message as a single string.
#' @keywords internal
#' @noRd
mail_message_build <- function(to, subject, body, cc = NULL, from) {
  mail_header_check(to, "to")
  mail_header_check(subject, "subject")
  mail_header_check(from, "from")
  if (!is.null(cc)) {
    mail_header_check(cc, "cc")
  }

  headers <- c(
    paste0("From: ", from),
    paste0("To: ", paste(to, collapse = ", ")),
    if (!is.null(cc)) paste0("Cc: ", paste(cc, collapse = ", ")),
    paste0("Subject: ", mail_header_encode(subject)),
    "MIME-Version: 1.0",
    "Content-Type: text/plain; charset=UTF-8",
    "Content-Transfer-Encoding: 8bit"
  )

  paste0(paste(headers, collapse = "\r\n"), "\r\n\r\n", body)
}

#' Exchange the stored refresh token for a Gmail access token
#'
#' The credential is deliberately narrow: a refresh token belonging to
#' `jinx@rladies.org` with the `gmail.send` scope, not a domain-wide
#' delegation. It can send as jinx and nothing else.
#'
#' @return An access token string.
#' @keywords internal
#' @noRd
mail_access_token <- function() {
  creds <- list(
    client_id = Sys.getenv("GOOGLE_CLIENT_ID"),
    client_secret = Sys.getenv("GOOGLE_CLIENT_SECRET"),
    refresh_token = Sys.getenv("GMAIL_REFRESH_TOKEN")
  )
  missing <- names(creds)[!nzchar(unlist(creds))]
  if (length(missing) > 0) {
    cli::cli_abort(
      "Gmail credentials are not configured: {toupper(missing)} unset"
    )
  }

  resp <- httr2::request("https://oauth2.googleapis.com") |>
    httr2::req_url_path_append("token") |>
    httr2::req_body_form(
      client_id = creds$client_id,
      client_secret = creds$client_secret,
      refresh_token = creds$refresh_token,
      grant_type = "refresh_token"
    ) |>
    httr2::req_perform() |>
    httr2::resp_body_json()

  token <- resp$access_token
  if (is.null(token)) {
    cli::cli_abort("Gmail token exchange returned no access token")
  }
  token
}

#' Send an email as jinx
#'
#' Sends plain text mail from `jinx@rladies.org`, cc'ing
#' `chapters@rladies.org` by default so the onboarding inbox keeps the
#' thread. jinx never sends *as* `chapters@`, which is why this needs
#' only a single account's `gmail.send` token rather than domain-wide
#' delegation.
#'
#' @param to Recipient address, or a vector of them.
#' @param subject Message subject.
#' @param body Plain text body.
#' @param cc Cc address. Defaults to `"chapters@rladies.org"`; pass
#'   `NULL` for none.
#' @param from Sender address. Defaults to `"jinx@rladies.org"`.
#' @return The sent message id (invisibly).
#' @export
mail_send <- function(
  to,
  subject,
  body,
  cc = "chapters@rladies.org",
  from = "jinx@rladies.org"
) {
  message <- mail_message_build(to, subject, body, cc, from)
  raw_message <- base64_url_encode(charToRaw(enc2utf8(message)))

  resp <- httr2::request("https://gmail.googleapis.com") |>
    httr2::req_url_path_append(
      "gmail",
      "v1",
      "users",
      "me",
      "messages",
      "send"
    ) |>
    httr2::req_auth_bearer_token(mail_access_token()) |>
    httr2::req_body_json(list(raw = raw_message)) |>
    httr2::req_perform() |>
    httr2::resp_body_json()

  cli::cli_alert_success("Sent {.val {subject}} to {toString(to)}")
  invisible(resp$id)
}
