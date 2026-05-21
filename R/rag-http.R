RAG_USER_AGENT <- "rladies-jinx-indexer/0.1 (+https://github.com/rladies/jinx)"

#' Fetch a URL as text with a single retry on transient failure
#'
#' Returns `NULL` for 4xx (treats them as not-found) and after retries on
#' 5xx / network errors. Used by source gatherers that prefer to skip
#' missing pages rather than abort the whole indexer run.
#'
#' @param url URL to fetch.
#' @param headers Optional named character vector of extra headers.
#' @param retries Number of retries on transient errors.
#' @return Response body as a character string, or `NULL` on failure.
#' @keywords internal
rag_fetch_text <- function(url, headers = character(), retries = 1L) {
  req <- httr2::request(url) |>
    httr2::req_user_agent(RAG_USER_AGENT) |>
    httr2::req_retry(max_tries = retries + 1L) |>
    httr2::req_error(is_error = function(resp) FALSE)
  if (length(headers)) {
    req <- httr2::req_headers(req, !!!as.list(headers))
  }
  resp <- tryCatch(httr2::req_perform(req), error = function(e) NULL)
  if (is.null(resp)) {
    return(NULL)
  }
  status <- httr2::resp_status(resp)
  if (status >= 400L) {
    if (status != 404L) {
      cli::cli_warn("GET {url} -> {status}")
    }
    return(NULL)
  }
  httr2::resp_body_string(resp)
}

#' Fetch a URL and parse its body as JSON
#'
#' @inheritParams rag_fetch_text
#' @return Parsed JSON, or `NULL` on failure.
#' @keywords internal
rag_fetch_json <- function(url, headers = character(), retries = 1L) {
  body <- rag_fetch_text(url, headers = headers, retries = retries)
  if (is.null(body)) {
    return(NULL)
  }
  tryCatch(
    jsonlite::fromJSON(body, simplifyVector = FALSE),
    error = function(e) {
      cli::cli_warn("JSON parse failed for {url}: {conditionMessage(e)}")
      NULL
    }
  )
}

#' Parse a date string (or numeric) to unix seconds, returning 0 on failure
#' @keywords internal
rag_parse_date <- function(raw) {
  parse_unix_date(raw) %||% 0L
}
