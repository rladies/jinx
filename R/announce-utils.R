#' Shorten a URL using the Short.io API
#'
#' @param uri URL to shorten.
#' @return Shortened URL string.
#' @export
short_url <- function(uri) {
  resp <- httr2::request("https://api.short.io/links") |>
    httr2::req_method("POST") |>
    httr2::req_headers(
      Authorization = Sys.getenv("SHORTIO"),
      accept = "application/json",
      `content-type` = "application/json"
    ) |>
    httr2::req_body_json(
      data = list(
        skipQS = FALSE,
        archived = FALSE,
        allowDuplicates = FALSE,
        originalURL = uri,
        domain = "go.rladies.org"
      )
    ) |>
    httr2::req_perform() |>
    httr2::resp_body_json()
  resp$shortURL
}

#' Convert tags to hashtag string
#'
#' @param tags Character vector of tags.
#' @return Single string with hashtags.
#' @export
tags2hash <- function(tags) {
  tags <- paste0("#", tags)
  tags <- sub("^#r$", "#rstats", tags, ignore.case = TRUE)
  tags <- sub(" |-", "", tags, ignore.case = TRUE)
  paste(tags, collapse = " ")
}

#' Create a formatted announcement message
#'
#' @param frontmatter Named list from YAML front matter (needs `title`,
#'   `description`, `tags`).
#' @param uri URL of the post.
#' @return Formatted message string.
#' @export
create_announcement_message <- function(frontmatter, uri) {
  emoji <- random_emoji()
  tags <- tags2hash(frontmatter$tags)

  glue::glue(
    "'{frontmatter$title}'

  {emoji} {frontmatter$description}

  \U0001F440 {uri}

  {tags}"
  )
}

#' Select a random emoji
#'
#' @return Single emoji character.
#' @export
random_emoji <- function() {
  emojis <- c(
    "\U1F4DD", "\U1F30D", "\U1F680", "\U1F4A1", "\U1F527",
    "\U1F31F", "\U1F914", "\U1F4F0", "\U1F4AD", "\U1F50D",
    "\U1F4C4", "\U1F4DA", "\U1F3AF", "\U1F9D0", "\U1F4BB",
    "\U1F4E2", "\U1F4B9", "\U1F4D1", "\U1F9ED", "\U1F9E0",
    "\U1F4BD", "\U1F4CA", "\U1F4F1", "\U1F389", "\U1F50A",
    "\U1F4D6", "\U1F5E8", "\U1F4FC", "\U1F9E9", "\U1F4BC",
    "\U1F575", "\U1F4AF", "\U1F4CC", "\U1F5C2", "\U1F5CE",
    "\U1F6C8", "\U1F9F0", "\U1F3AC", "\U1F92F", "\U1F4AE"
  )
  sample(emojis, 1)
}
