#' Check blog URLs and RSS feeds for broken links
#'
#' @param blogs_path Path to directory containing blog JSON files.
#' @return A data frame with columns `file`, `url`, `rss_feed`,
#'   `url_status`, `rss_status`.
#' @export
check_blog_links <- function(blogs_path) {
  files <- list.files(blogs_path, pattern = "\\.json$", full.names = TRUE)

  results <- lapply(files, function(f) {
    entry <- tryCatch(
      jsonlite::read_json(f, simplifyVector = FALSE),
      error = function(e) return(NULL)
    )
    if (is.null(entry)) {
      return(data.frame(
        file = basename(f),
        url = NA,
        rss_feed = NA,
        url_status = NA_integer_,
        rss_status = NA_integer_,
        stringsAsFactors = FALSE
      ))
    }

    url_status <- check_url_status(entry$url)
    rss_status <- if (!is.null(entry$rss_feed) && nzchar(entry$rss_feed)) {
      check_url_status(entry$rss_feed)
    } else {
      NA_integer_
    }

    data.frame(
      file = basename(f),
      url = entry$url %||% NA_character_,
      rss_feed = entry$rss_feed %||% NA_character_,
      url_status = url_status,
      rss_status = rss_status,
      stringsAsFactors = FALSE
    )
  })

  result <- do.call(rbind, results)
  broken <- result[!is.na(result$url_status) & result$url_status >= 400, ]
  if (nrow(broken) > 0) {
    cli::cli_alert_warning("Found {nrow(broken)} broken blog URL{?s}")
  } else {
    cli::cli_alert_success("All blog URLs are healthy")
  }
  result
}

check_url_status <- function(url) {
  if (is.null(url) || !nzchar(url)) {
    return(NA_integer_)
  }
  tryCatch(
    {
      resp <- httr2::request(url) |>
        httr2::req_method("HEAD") |>
        httr2::req_timeout(10) |>
        httr2::req_error(is_error = function(resp) FALSE) |>
        httr2::req_perform()
      httr2::resp_status(resp)
    },
    error = function(e) 999L
  )
}
