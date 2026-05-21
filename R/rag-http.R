RAG_USER_AGENT <- "rladies-jinx-indexer/0.1 (+https://github.com/rladies/jinx)"

#' Perform an httr2 request and return its body as text
#'
#' Treats every non-2xx response as a soft failure: warns on
#' unexpected statuses, returns `NULL` on 4xx/5xx and on network
#' errors. Designed so source gatherers can skip a missing page
#' rather than abort the whole indexer run.
#'
#' @param req An [httr2::request] object (already configured with
#'   path, query, auth, body, etc.).
#' @param retries Number of retries on transient errors.
#' @return Response body as a character string, or `NULL` on failure.
#' @keywords internal
rag_fetch_text <- function(req, retries = 1L) {
  req <- req |>
    httr2::req_user_agent(RAG_USER_AGENT) |>
    httr2::req_retry(max_tries = retries + 1L) |>
    httr2::req_error(is_error = function(resp) FALSE)
  resp <- tryCatch(httr2::req_perform(req), error = function(e) NULL)
  if (is.null(resp)) {
    return(NULL)
  }
  status <- httr2::resp_status(resp)
  if (status >= 400L) {
    if (status != 404L) {
      cli::cli_warn("GET {req$url} -> {status}")
    }
    return(NULL)
  }
  httr2::resp_body_string(resp)
}

#' Perform an httr2 request and parse its body as JSON
#' @inheritParams rag_fetch_text
#' @return Parsed JSON, or `NULL` on failure.
#' @keywords internal
rag_fetch_json <- function(req, retries = 1L) {
  body <- rag_fetch_text(req, retries = retries)
  if (is.null(body)) {
    return(NULL)
  }
  tryCatch(
    jsonlite::fromJSON(body, simplifyVector = FALSE),
    error = function(e) {
      cli::cli_warn("JSON parse failed for {req$url}: {conditionMessage(e)}")
      NULL
    }
  )
}

#' Parse a date string (or numeric) to unix seconds, returning 0 on failure
#' @keywords internal
rag_parse_date <- function(raw) {
  parse_unix_date(raw) %||% 0L
}
