#' Announce a blog post across multiple platforms
#'
#' Reads YAML front matter from a blog post, creates an announcement
#' message, and posts to selected platforms.
#'
#' @param post File path to the blog post (markdown with YAML front matter).
#' @param platforms Character vector of platforms to post to.
#'   Defaults to all: `"bluesky"`, `"linkedin"`, `"mastodon"`.
#' @param newsletter Logical, whether to also send a newsletter. Defaults
#'   to `TRUE`.
#' @return Invisibly returns a named list with the posting result for each
#'   platform.
#' @export
announce_post <- function(
  post,
  platforms = c("bluesky", "linkedin", "mastodon"),
  newsletter = TRUE
) {
  if (is.null(post) || !file.exists(post)) {
    cli::cli_abort("Post file not found: {.path {post}}")
  }

  frontmatter <- rmarkdown::yaml_front_matter(post)

  url <- sprintf(
    "https://rladies.org/blog/%s/%s",
    basename(dirname(dirname(post))),
    frontmatter$slug
  )

  image <- file.path(dirname(post), frontmatter$image)
  if (!file.exists(image)) {
    image <- NULL
  }

  short <- tryCatch(
    short_url(url),
    error = function(e) {
      cli::cli_alert_warning("URL shortening failed, using full URL")
      url
    }
  )

  body <- create_announcement_message(frontmatter, short)

  if ("bluesky" %in% platforms) {
    tryCatch(
      post_bluesky(body, image, frontmatter$image_alt),
      error = function(e) cli::cli_alert_danger("Bluesky failed: {e$message}")
    )
  }

  if ("linkedin" %in% platforms) {
    tryCatch(
      {
        author <- li_urn_me()
        li_post_write(author, body, image, frontmatter$image_alt %||% "")
      },
      error = function(e) cli::cli_alert_danger("LinkedIn failed: {e$message}")
    )
  }

  if ("mastodon" %in% platforms) {
    tryCatch(
      post_mastodon(body, image, frontmatter$image_alt),
      error = function(e) cli::cli_alert_danger("Mastodon failed: {e$message}")
    )
  }

  if (newsletter) {
    tryCatch(
      send_newsletter(frontmatter, url),
      error = function(e) {
        cli::cli_alert_danger("Newsletter failed: {e$message}")
      }
    )
  }

  invisible()
}
