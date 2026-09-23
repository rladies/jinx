#' Create a chapter mailbox in Google Workspace
#'
#' Asks the jinx worker to provision `<city>@rladies.org` in the
#' `/Chapters` organisational unit. The Workspace service account key
#' lives in the worker rather than in CI, so this call carries only the
#' worker API key: the most a stolen CI token can do is ask for a
#' mailbox whose name passes the worker's validation.
#'
#' The signing and Directory API calls could be done here in R - `openssl`
#' signs RS256 perfectly well - but that would require the service account
#' key on the Actions runner that runs this function, which is the thing
#' the current arrangement avoids. `worker/src/workspace.js` carries the
#' full reasoning; it is a deliberate exception to moving worker logic
#' into this package.
#'
#' The generated password is never returned. The account is created with
#' change-password-at-next-login set, and the onboarding team issues the
#' handover from the Admin console.
#'
#' @param city Chapter city. The worker transliterates and validates it,
#'   and refuses reserved addresses.
#' @param given_name Given name on the account. Defaults to `"RLadies+"`.
#' @param family_name Family name on the account. Defaults to the city.
#' @param base_url Worker base URL.
#' @param api_key Worker API key. Defaults to the `JINX_API_KEY`
#'   environment variable.
#' @return The created address (invisibly).
#' @export
chapter_mailbox_create <- function(
  city,
  given_name = NULL,
  family_name = NULL,
  base_url = "https://jinx.rladies.org",
  api_key = Sys.getenv("JINX_API_KEY")
) {
  if (!nzchar(api_key)) {
    cli::cli_abort("JINX_API_KEY is not set")
  }

  body <- list(city = city)
  if (!is.null(given_name)) {
    body$givenName <- given_name
  }
  if (!is.null(family_name)) {
    body$familyName <- family_name
  }

  resp <- httr2::request(base_url) |>
    httr2::req_url_path_append("workspace", "mailbox") |>
    httr2::req_auth_bearer_token(api_key) |>
    httr2::req_body_json(body) |>
    httr2::req_error(is_error = function(resp) FALSE) |>
    httr2::req_perform()

  parsed <- tryCatch(
    httr2::resp_body_json(resp),
    error = function(e) list()
  )

  if (httr2::resp_status(resp) != 201) {
    cli::cli_abort(c(
      "Could not create the mailbox for {.val {city}}.",
      "x" = parsed$error %or%
        glue::glue(
          "worker returned {httr2::resp_status(resp)}"
        )
    ))
  }

  cli::cli_alert_success("Created mailbox {.val {parsed$email}}")
  invisible(parsed$email)
}
