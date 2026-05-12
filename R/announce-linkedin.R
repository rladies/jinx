#' Escape special characters for LinkedIn API
#'
#' @param x Character string to escape.
#' @return Escaped string.
#' @keywords internal
#' @noRd
escape_linkedin_chars <- function(x) {
  chars <- c(
    "\\|",
    "\\{",
    "\\}",
    "\\@",
    "\\[",
    "\\]",
    "\\(",
    "\\)",
    "\\<",
    "\\>",
    "\\#",
    "\\\\",
    "\\*",
    "\\_",
    "\\~"
  )
  p <- stats::setNames(paste0("\\", chars), chars)
  stringr::str_replace_all(x, p)
}

#' Get LinkedIn API version string
#'
#' @return Version string in YYYYMM format.
#' @export
li_get_version <- function() {
  version_date <- lubridate::rollback(lubridate::today())
  paste0(
    lubridate::year(version_date),
    stringr::str_pad(lubridate::month(version_date), 2, pad = "0")
  )
}

li_client <- function() {
  httr2::oauth_client(
    name = "rladies_linkedIn",
    token_url = "https://www.linkedin.com/oauth/v2/accessToken",
    id = Sys.getenv("LI_CLIENT_ID"),
    secret = Sys.getenv("LI_CLIENT_SECRET")
  )
}

#' Perform LinkedIn OAuth authentication
#'
#' Interactive OAuth2 flow for obtaining a LinkedIn token.
#'
#' @return OAuth token object.
#' @export
li_oauth <- function() {
  auth_url <- httr2::oauth_flow_auth_code_url(
    client = li_client(),
    auth_url = "https://www.linkedin.com/oauth/v2/authorization",
    state = "whoruntheworldgirls"
  )

  httr2::oauth_flow_auth_code(
    client = li_client(),
    auth_url = auth_url,
    redirect_uri = "http://localhost:1444/",
    scope = paste("email", "openid", "profile", "w_member_social"),
    pkce = FALSE
  )
}

li_req_auth <- function(req, token = Sys.getenv("LI_TOKEN")) {
  httr2::req_auth_bearer_token(req, token)
}

#' Create a base LinkedIn API request
#'
#' @param endpoint_version API version path. Defaults to `"rest"`.
#' @param ... Passed to `li_req_auth()`.
#' @return Configured httr2 request.
#' @export
li_req <- function(endpoint_version = "rest", ...) {
  httr2::request("https://api.linkedin.com") |>
    httr2::req_url_path_append(endpoint_version) |>
    httr2::req_headers(
      "LinkedIn-Version" = li_get_version(),
      "X-Restli-Protocol-Version" = "2.0.0",
      "Content-Type" = "application/json"
    ) |>
    li_req_auth(...)
}

#' Get the LinkedIn URN for the authenticated user
#'
#' @return URN string like `"urn:li:person:abc123"`.
#' @export
li_urn_me <- function() {
  id <- li_req("v2") |>
    httr2::req_url_path_append("userinfo") |>
    httr2::req_auth_bearer_token(Sys.getenv("LI_TOKEN")) |>
    httr2::req_url_query(projection = "(sub)") |>
    httr2::req_perform() |>
    httr2::resp_body_json() |>
    unlist()
  paste0("urn:li:person:", id)
}

#' Post to LinkedIn
#'
#' @param author LinkedIn URN of the author.
#' @param text Post text.
#' @param image Optional file path to an image.
#' @param image_alt Alt text for the image.
#' @return LinkedIn post ID (invisibly).
#' @export
li_post_write <- function(author, text, image = NULL, image_alt = "") {
  text <- escape_linkedin_chars(text)

  body <- list(
    author = author,
    lifecycleState = "PUBLISHED",
    commentary = text,
    visibility = "PUBLIC",
    distribution = list(
      feedDistribution = "MAIN_FEED",
      targetEntities = list(),
      thirdPartyDistributionChannels = list()
    ),
    isReshareDisabledByAuthor = FALSE
  )

  if (!is.null(image)) {
    body$content <- list(
      media = list(
        id = li_media_upload(author, image),
        title = image_alt
      )
    )
  }

  resp <- li_req() |>
    httr2::req_url_path_append("posts") |>
    httr2::req_body_json(body, auto_unbox = TRUE) |>
    httr2::req_retry(
      is_transient = \(x) httr2::resp_status(x) %in% c(401, 403, 425, 429),
      max_tries = 10,
      backoff = ~3
    ) |>
    httr2::req_perform() |>
    httr2::resp_header("x-restli-id")

  post_url <- file.path("https://www.linkedin.com/feed/update/", resp)
  cli::cli_alert_success("Posted to LinkedIn: {.url {post_url}}")
  invisible(resp)
}

#' Upload media to LinkedIn
#'
#' @param author LinkedIn URN of the owner.
#' @param media File path to the image.
#' @return LinkedIn image ID string.
#' @export
li_media_upload <- function(author, media) {
  r <- li_req() |>
    httr2::req_url_path_append("images") |>
    httr2::req_url_query(action = "initializeUpload") |>
    httr2::req_body_json(
      list(initializeUploadRequest = list(owner = author)),
      auto_unbox = TRUE
    ) |>
    httr2::req_perform() |>
    httr2::resp_body_json()

  httr2::request(r$value$uploadUrl) |>
    httr2::req_body_file(media) |>
    httr2::req_perform()

  r$value$image
}
