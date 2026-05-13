#' Send a newsletter via ConvertKit
#'
#' @param frontmatter Named list with `seo`, `image`, `title` fields.
#' @param url URL of the post.
#' @return API response (invisibly).
#' @export
announce_send_newsletter <- function(frontmatter, url) {
  httr2::request("https://api.convertkit.com/v3/broadcasts") |>
    httr2::req_body_json(
      list(
        public = TRUE,
        api_secret = Sys.getenv("KIT_SECRET"),
        description = frontmatter$seo,
        thumbnail_url = file.path(url, frontmatter$image),
        subject = frontmatter$title,
        content = glue::glue(
          "<p>{frontmatter$seo}</p>",
          "<p><a href='{url}'>Read more</a></p>"
        ),
        send_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ")
      )
    ) |>
    httr2::req_perform()

  cli::cli_alert_success("Newsletter sent: {.val {frontmatter$title}}")
  invisible()
}
