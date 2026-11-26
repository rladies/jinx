#' Default User-Agent string used by the RAG indexer's HTTP calls
#'
#' Exposed as a function (rather than a hidden package constant) so
#' every helper that needs a User-Agent default can list it in its
#' signature, e.g. `rag_request(url, user_agent = rag_user_agent())`.
#'
#' @return Character scalar.
#' @keywords internal
rag_user_agent <- function() {
  paste0(
    "rladies-jinx-indexer/",
    utils::packageVersion("jinx"),
    " (+https://github.com/rladies/jinx)"
  )
}

#' Build a plain httr2 request with the indexer's User-Agent attached
#'
#' Use for "bare" URL fetches (sitemaps, Hugo pages, generic JSON
#' feeds) that don't go through one of the API-specific base-request
#' helpers (`cloudflare_request`, `github_request`, `youtube_request`).
#'
#' @param url Target URL.
#' @param user_agent User-Agent header to attach.
#' @return [httr2::request] object.
#' @keywords internal
rag_request <- function(url, user_agent = rag_user_agent()) {
  httr2::request(url) |>
    httr2::req_user_agent(user_agent)
}

#' Perform an httr2 request and return its body as text
#'
#' Treats every non-2xx response as a soft failure: warns on
#' unexpected statuses, returns `NULL` on 4xx/5xx and on network
#' errors. Designed so source gatherers can skip a missing page
#' rather than abort the whole indexer run.
#'
#' Caller is responsible for attaching a User-Agent (via
#' `rag_request()` or one of the API-specific base-request helpers).
#'
#' @param req An [httr2::request] object (already configured with
#'   path, query, auth, body, headers).
#' @param retries Number of retries on transient errors.
#' @return Response body as a character string, or `NULL` on failure.
#' @keywords internal
rag_fetch_text <- function(req, retries = 1L) {
  req <- req |>
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
  parse_unix_date(raw) %or% 0L
}

#' Worker endpoint that fetches a public URL on the indexer's behalf
#'
#' Derived from `JINX_WORKER_URL` rather than configured separately: the
#' workflows that need the proxy already carry that secret and the Worker's
#' API key, so routing through it costs no new configuration.
#'
#' @return Character scalar URL, `""` when `JINX_WORKER_URL` is unset.
#' @keywords internal
#' @noRd
rag_proxy_url <- function() {
  base <- Sys.getenv("JINX_WORKER_URL")
  if (is_blank(base)) {
    return("")
  }
  paste0(sub("/+$", "", base), "/content/fetch")
}

#' Build a request that fetches `url` through the jinx Worker
#'
#' Several curated blogs sit behind Cloudflare with Bot Fight Mode on, which
#' managed-challenges the Azure ranges GitHub Actions runs on - those feeds
#' answered every scheduled poll with a 403. A Worker's egress is scored
#' differently, so the same request from there succeeds.
#'
#' Falls back to a direct request whenever the proxy is not configured, so
#' local runs and tests need no Worker.
#'
#' @param url Target URL.
#' @param proxy Worker `/content/fetch` endpoint.
#' @param key Bearer key for the Worker's HTTP API.
#' @return [httr2::request] object.
#' @keywords internal
rag_request_proxied <- function(
  url,
  proxy = rag_proxy_url(),
  key = Sys.getenv("JINX_WORKER_API_KEY")
) {
  if (is_blank(proxy) || is_blank(key)) {
    return(rag_request(url))
  }
  httr2::request(proxy) |>
    httr2::req_user_agent(rag_user_agent()) |>
    httr2::req_auth_bearer_token(key) |>
    httr2::req_body_json(list(url = url, user_agent = rag_user_agent()))
}
