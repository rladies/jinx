#' Verify that social media handles exist
#'
#' Performs HTTP HEAD requests to check if profiles resolve.
#'
#' @param entry Named list representing a directory entry, with a
#'   `social_media` sub-list containing handles/URLs.
#' @return A data frame with columns `platform`, `handle`, `status`,
#'   and `valid`.
#' @export
directory_verify_handles <- function(entry) {
  social <- entry$social_media
  if (is.null(social)) {
    return(directory_empty_social_df())
  }

  results <- lapply(
    names(social),
    function(platform) directory_verify_one_handle(platform, social[[platform]])
  )

  do.call(rbind, Filter(Negate(is.null), results))
}

directory_verify_one_handle <- function(platform, handle) {
  if (is.null(handle) || !nzchar(handle)) {
    return(NULL)
  }

  url_builder <- social_url_builders[[platform]]
  if (is.null(url_builder)) {
    return(directory_social_row(platform, handle, NA_integer_, NA))
  }

  url <- url_builder(handle)
  if (is.na(url)) {
    return(directory_social_row(platform, handle, NA_integer_, FALSE))
  }

  status <- head_status(url)
  directory_social_row(platform, handle, status, !is.na(status) && status < 400)
}

social_url_builders <- list(
  twitter = function(h) paste0("https://x.com/", sub("^@", "", h)),
  github = function(h) paste0("https://github.com/", sub("^@", "", h)),
  linkedin = function(h) {
    if (grepl("^https?://", h)) h else paste0("https://www.linkedin.com/in/", h)
  },
  mastodon = function(h) {
    if (grepl("^https?://", h)) {
      return(h)
    }
    parts <- strsplit(sub("^@", "", h, fixed = TRUE), "@")[[1]]
    if (length(parts) == 2) {
      paste0("https://", parts[2], "/@", parts[1])
    } else {
      NA_character_
    }
  }
)

directory_empty_social_df <- function() {
  data.frame(
    platform = character(),
    handle = character(),
    status = integer(),
    valid = logical(),
    stringsAsFactors = FALSE
  )
}

directory_social_row <- function(platform, handle, status, valid) {
  data.frame(
    platform = platform,
    handle = handle,
    status = status,
    valid = valid,
    stringsAsFactors = FALSE
  )
}

head_status <- function(url) {
  tryCatch(
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
}
