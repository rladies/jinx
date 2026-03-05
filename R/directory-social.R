#' Verify that social media handles exist
#'
#' Performs HTTP HEAD requests to check if profiles resolve.
#'
#' @param entry Named list representing a directory entry, with a
#'   `social_media` sub-list containing handles/URLs.
#' @return A data frame with columns `platform`, `handle`, `status`,
#'   and `valid`.
#' @export
verify_social_handles <- function(entry) {
  social <- entry$social_media
  if (is.null(social)) {
    return(data.frame(
      platform = character(), handle = character(),
      status = integer(), valid = logical(),
      stringsAsFactors = FALSE
    ))
  }

  checks <- list(
    twitter = function(h) paste0("https://x.com/", sub("^@", "", h)),
    github = function(h) paste0("https://github.com/", sub("^@", "", h)),
    linkedin = function(h) {
      if (grepl("^https?://", h)) h
      else paste0("https://www.linkedin.com/in/", h)
    },
    mastodon = function(h) {
      if (grepl("^https?://", h)) return(h)
      parts <- strsplit(sub("^@", "", h), "@")[[1]]
      if (length(parts) == 2) {
        paste0("https://", parts[2], "/@", parts[1])
      } else {
        NA_character_
      }
    }
  )

  results <- lapply(names(social), function(platform) {
    handle <- social[[platform]]
    if (is.null(handle) || !nzchar(handle)) {
      return(NULL)
    }

    url_builder <- checks[[platform]]
    if (is.null(url_builder)) {
      return(data.frame(
        platform = platform, handle = handle,
        status = NA_integer_, valid = NA,
        stringsAsFactors = FALSE
      ))
    }

    url <- url_builder(handle)
    if (is.na(url)) {
      return(data.frame(
        platform = platform, handle = handle,
        status = NA_integer_, valid = FALSE,
        stringsAsFactors = FALSE
      ))
    }

    status <- tryCatch(
      {
        resp <- httr2::request(url) |>
          httr2::req_method("HEAD") |>
          httr2::req_timeout(10) |>
          httr2::req_error(is_error = function(resp) FALSE) |>
          httr2::req_perform()
        httr2::resp_status(resp)
      },
      error = function(e) NA_integer_
    )

    data.frame(
      platform = platform,
      handle = handle,
      status = status,
      valid = !is.na(status) && status < 400,
      stringsAsFactors = FALSE
    )
  })

  do.call(rbind, Filter(Negate(is.null), results))
}
