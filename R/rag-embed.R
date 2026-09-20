#' Default Workers AI chat/instruct model
#'
#' Single source of truth for the model id, since Workers AI model
#' retirements have previously broken callers that hardcoded it in
#' multiple places.
#'
#' @return Character scalar model id.
#' @keywords internal
#' @noRd
workers_ai_chat_model <- function() {
  "@cf/meta/llama-3.1-8b-instruct-fast"
}

#' Embed texts with a Cloudflare Workers AI model
#'
#' Calls the Cloudflare REST endpoint
#' `accounts/{id}/ai/run/{model}` and returns the embedding vectors.
#' Custom because [cloudflarer](https://drmowinckels.r-universe.dev/cloudflarer)
#' does not wrap Workers AI inference; built on its [cloudflarer::cf_request()]
#' and [cloudflarer::cf_resp()] for consistent auth and error handling.
#'
#' @param texts Character vector of texts.
#' @param account_id Cloudflare account ID.
#' @param api_token Cloudflare API token.
#' @param model Workers AI embedding model.
#' @return List of numeric vectors, one per input text.
#' @export
cloudflare_embed <- function(
  texts,
  account_id,
  api_token,
  model = "@cf/baai/bge-base-en-v1.5"
) {
  body <- cloudflarer::cf_request(
    c("accounts", account_id, "ai", "run", model),
    token = api_token
  ) |>
    httr2::req_retry(max_tries = 3) |>
    httr2::req_body_json(list(text = as.list(texts))) |>
    httr2::req_perform() |>
    cloudflarer::cf_resp()
  lapply(body$data, as.numeric)
}

#' Generate chat-completion text with a Cloudflare Workers AI model
#'
#' Calls the Cloudflare REST endpoint `accounts/{id}/ai/run/{model}` with a
#' chat-style `messages` array and returns the generated text. Sibling of
#' [cloudflare_embed()] - same auth/retry/error-handling idiom, built on
#' [cloudflarer::cf_request()] and [cloudflarer::cf_resp()] because
#' cloudflarer does not wrap Workers AI inference.
#'
#' @param messages List of chat messages, each `list(role = , content = )`.
#' @param account_id Cloudflare account ID.
#' @param api_token Cloudflare API token.
#' @param model Workers AI chat/instruct model.
#' @param max_tokens Maximum tokens to generate.
#' @return Character scalar with the model's response text.
#' @export
cloudflare_generate <- function(
  messages,
  account_id,
  api_token,
  model = workers_ai_chat_model(),
  max_tokens = 256
) {
  body <- cloudflarer::cf_request(
    c("accounts", account_id, "ai", "run", model),
    token = api_token
  ) |>
    httr2::req_retry(max_tries = 3) |>
    httr2::req_body_json(list(messages = messages, max_tokens = max_tokens)) |>
    httr2::req_perform() |>
    cloudflarer::cf_resp()
  body$response
}

#' Upsert vectors into a Cloudflare Vectorize index
#'
#' Custom because [cloudflarer](https://drmowinckels.r-universe.dev/cloudflarer)
#' does not wrap Vectorize v2; built on its [cloudflarer::cf_request()] and
#' [cloudflarer::cf_resp()] for consistent auth and error handling.
#'
#' @param vectors List of vector records, each with `id`, `values`, `metadata`.
#' @param account_id Cloudflare account ID.
#' @param api_token Cloudflare API token.
#' @param index_name Vectorize index name.
#' @return The unwrapped `result` payload from the Cloudflare response.
#' @export
cloudflare_vectorize_upsert <- function(
  vectors,
  account_id,
  api_token,
  index_name
) {
  ndjson <- paste(
    vapply(
      vectors,
      jsonlite::toJSON,
      character(1),
      auto_unbox = TRUE,
      null = "null"
    ),
    collapse = "\n"
  )
  cloudflarer::cf_request(
    c(
      "accounts",
      account_id,
      "vectorize",
      "v2",
      "indexes",
      index_name,
      "upsert"
    ),
    token = api_token
  ) |>
    httr2::req_retry(max_tries = 3) |>
    httr2::req_body_raw(ndjson, type = "application/x-ndjson") |>
    httr2::req_perform() |>
    cloudflarer::cf_resp()
}

#' Discover the Cloudflare account ID for a token
#'
#' Fails if the token has access to zero or more than one account.
#'
#' @param api_token Cloudflare API token.
#' @return Account ID string.
#' @export
cloudflare_account_id <- function(api_token) {
  accounts <- cloudflarer::cf_list_accounts(token = api_token, as_df = FALSE)
  if (length(accounts) == 0L) {
    cli::cli_abort("Cloudflare token has no accessible accounts.")
  }
  if (length(accounts) > 1L) {
    cli::cli_abort(c(
      "Token has access to {length(accounts)} accounts.",
      i = "Set CLOUDFLARE_ACCOUNT_ID explicitly."
    ))
  }
  accounts[[1]]$id
}

#' Stable vector ID for a chunk
#'
#' Matches the JS indexer scheme: first 32 hex chars of
#' `sha256("{repo}|{path}|{chunk_idx}")`.
#'
#' @param repo Source repo (e.g. `"rladies/rladiesguide"`).
#' @param path Path within the source (e.g. `/getting-started/`).
#' @param chunk_idx Zero-based chunk index within the document.
#' @return 32-character hex string.
#' @export
rag_chunk_id <- function(repo, path, chunk_idx) {
  key <- paste(repo, path, chunk_idx, sep = "|")
  hex <- paste(
    as.character(unclass(openssl::sha256(charToRaw(key)))),
    collapse = ""
  )
  substr(hex, 1L, 32L)
}
