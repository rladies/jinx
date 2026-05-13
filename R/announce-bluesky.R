#' Post an announcement to Bluesky
#'
#' @param text Post text.
#' @param image Optional file path to an image.
#' @param image_alt Alt text for the image.
#' @return Post response (invisibly).
#' @export
announce_post_bluesky <- function(text, image = NULL, image_alt = NULL) {
  resp <- bskyr::bs_post(
    text = text,
    images = image,
    images_alt = image_alt
  )
  cli::cli_alert_success("Posted to Bluesky")
  invisible(resp)
}
