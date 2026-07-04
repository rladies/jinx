#' Check blog URLs and RSS feeds for broken links
#'
#' @param blogs_path Path to directory containing blog JSON files.
#' @return A data frame with columns `file`, `url`, `rss_feed`,
#'   `url_status`, `rss_status`.
#' @export
blog_check_links <- function(blogs_path) {
  files <- list.files(blogs_path, pattern = "\\.json$", full.names = TRUE)

  results <- lapply(files, function(f) {
    entry <- tryCatch(
      jsonlite::read_json(f, simplifyVector = FALSE),
      error = function(e) NULL
    )
    blog_link_row(basename(f), entry)
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

#' Build one link-status row for a blog entry
#'
#' Shared by the local and repo link checkers. A `NULL` entry (unreadable
#' JSON) yields a row of `NA` statuses rather than erroring.
#'
#' @param file The entry's file name.
#' @param entry Parsed blog entry list, or `NULL`.
#' @return A one-row data frame.
#' @keywords internal
#' @noRd
blog_link_row <- function(file, entry) {
  rss <- entry$rss_feed
  data.frame(
    file = file,
    url = entry$url %||% NA_character_,
    rss_feed = rss %||% NA_character_,
    url_status = check_url_status(entry$url),
    rss_status = if (!is.null(rss) && nzchar(rss)) {
      check_url_status(rss)
    } else {
      NA_integer_
    },
    stringsAsFactors = FALSE
  )
}

#' Check community blog links from the awesome-rladies-creations repo
#'
#' Lists the blog entry JSON files in the content directory via the GitHub
#' API and checks each entry's `url` and `rss_feed` for broken links.
#'
#' @param org,repo,content_path Location of the blog entry JSON files.
#' @return A data frame with columns `file`, `url`, `rss_feed`,
#'   `url_status`, `rss_status`.
#' @export
blog_check_links_repo <- function(
  org = "rladies",
  repo = "awesome-rladies-creations",
  content_path = "data/content"
) {
  files <- gh::gh(
    "GET /repos/{owner}/{repo}/contents/{path}",
    owner = org,
    repo = repo,
    path = content_path
  )
  entries <- Filter(
    function(f) identical(f$type, "file") && grepl("\\.json$", f$name),
    files
  )

  results <- lapply(entries, function(f) {
    entry <- tryCatch(
      jsonlite::fromJSON(f$download_url, simplifyVector = FALSE),
      error = function(e) NULL
    )
    blog_link_row(f$name, entry)
  })

  do.call(rbind, results)
}

#' Format a blog link-check report as chat markdown
#'
#' @param report A data frame from [blog_check_links_repo()], or `NULL`.
#' @return Character string of markdown.
#' @keywords internal
#' @noRd
blog_links_report <- function(report) {
  if (is.null(report) || nrow(report) == 0) {
    return("No community blog entries found.")
  }
  broken <- report[
    (!is.na(report$url_status) & report$url_status >= 400) |
      (!is.na(report$rss_status) & report$rss_status >= 400),
  ]
  if (nrow(broken) == 0) {
    return(glue::glue(
      "All {nrow(report)} community blog links are healthy. \U0001f389"
    ))
  }
  lines <- glue::glue_data(
    broken,
    "- **{file}**: url `{url_status}`, rss `{rss_status}`"
  )
  paste0(
    "## Broken blog links (",
    nrow(broken),
    ")\n\n",
    paste(lines, collapse = "\n")
  )
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
