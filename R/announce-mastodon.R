#' Post an announcement to Mastodon
#'
#' @param text Post text.
#' @param image Optional file path to an image.
#' @param image_alt Alt text for the image.
#' @return Post response (invisibly).
#' @export
announce_post_mastodon <- function(text, image = NULL, image_alt = NULL) {
  resp <- rtoot::post_toot(
    status = text,
    media = image,
    alt_text = image_alt,
    visibility = "public",
    language = "US-en"
  )
  cli::cli_alert_success("Posted to Mastodon")
  invisible(resp)
}
