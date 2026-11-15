#' List Workers scripts deployed on the account
#'
#' Thin wrapper over [cloudflarer::cf_list_workers_scripts()].
#'
#' @param account_id Cloudflare account ID. Defaults to env
#'   `CLOUDFLARE_ACCOUNT_ID`.
#' @param token Cloudflare API token. Defaults to env
#'   `CLOUDFLARE_OPS_API_TOKEN`, falling back to `CLOUDFLARE_API_TOKEN`.
#' @return Data frame of Workers script records.
#' @export
cf_ops_list_workers_scripts <- function(
  account_id = Sys.getenv("CLOUDFLARE_ACCOUNT_ID"),
  token = cf_ops_token()
) {
  cloudflarer::cf_list_workers_scripts(account_id = account_id, token = token)
}

cf_ops_token <- function() {
  token <- Sys.getenv("CLOUDFLARE_OPS_API_TOKEN", unset = "")
  if (nzchar(token)) {
    return(token)
  }
  Sys.getenv("CLOUDFLARE_API_TOKEN")
}

#' Query Workers invocation/error/CPU metrics
#'
#' Thin wrapper over [cloudflarer::cf_workers_invocations()], defaulting
#' `script_name` to `"jinx"` (matches `wrangler.jsonc`'s worker name)
#' rather than requiring the caller to know it.
#'
#' @param account_id Cloudflare account ID. Defaults to env
#'   `CLOUDFLARE_ACCOUNT_ID`.
#' @param since,until Date range. Defaults to the last day.
#' @param script_name Worker script name. Defaults to `"jinx"`.
#' @param token Cloudflare API token. Defaults to env
#'   `CLOUDFLARE_OPS_API_TOKEN`, falling back to `CLOUDFLARE_API_TOKEN`.
#' @return Data frame with columns `date`, `script`, `requests`, `errors`,
#'   `subrequests`, `cpu_p50_us`, `cpu_p99_us`.
#' @export
cf_ops_workers_invocations <- function(
  account_id = Sys.getenv("CLOUDFLARE_ACCOUNT_ID"),
  since = Sys.Date() - 1,
  until = Sys.Date(),
  script_name = "jinx",
  token = cf_ops_token()
) {
  cloudflarer::cf_workers_invocations(
    account_id = account_id,
    since = since,
    until = until,
    script_name = script_name,
    token = token
  )
}

#' Format Workers invocation metrics as a markdown table
#'
#' @param df Data frame from [cf_ops_workers_invocations()].
#' @return Character string with markdown-formatted report.
#' @export
cf_ops_format_workers_report <- function(df) {
  if (is.null(df) || nrow(df) == 0) {
    return("No Workers invocation data available.")
  }
  paste(
    "| Date | Requests | Errors | Subrequests | p50 CPU (us) | p99 CPU (us) |",
    "|------|----------|--------|-------------|--------------|--------------|",
    paste(
      glue::glue_data(
        df,
        "| {date} | {requests} | {errors} | {subrequests}",
        " | {cpu_p50_us} | {cpu_p99_us} |"
      ),
      collapse = "\n"
    ),
    sep = "\n"
  )
}

#' List keys in a Cloudflare KV namespace
#'
#' Read-only, for interactive/console use during an incident — not wired
#' into a `/jinx` command, since KV namespaces on this account
#' (`SLACK_TOKENS`, `AIRTABLE_BASES`) hold operational secrets, and a
#' chat-triggered arbitrary-namespace read is a real exfiltration path.
#'
#' @param account_id Cloudflare account ID. Defaults to env
#'   `CLOUDFLARE_ACCOUNT_ID`.
#' @param namespace_id KV namespace ID.
#' @param prefix Optional key-name prefix filter.
#' @param token Cloudflare API token. Defaults to env
#'   `CLOUDFLARE_OPS_API_TOKEN`, falling back to `CLOUDFLARE_API_TOKEN`.
#' @return Data frame of key records.
#' @export
cf_ops_list_kv_keys <- function(
  account_id = Sys.getenv("CLOUDFLARE_ACCOUNT_ID"),
  namespace_id,
  prefix = NULL,
  token = cf_ops_token()
) {
  cloudflarer::cf_list_kv_keys(
    account_id = account_id,
    namespace_id = namespace_id,
    prefix = prefix,
    token = token
  )
}

#' Retry a Cloudflare call that failed for a transient reason
#'
#' `cloudflarer` builds its requests without `httr2::req_retry()`, and
#' its KV functions expose neither the request nor a `...`, so jinx
#' cannot reach in and add one the way the Airtable and Slack calls do.
#' A DNS blip or a 503 therefore reaches the caller as a hard error.
#' For the KV reads and writes that carry a schedule's "what have I
#' already done" state that is worse than it sounds: the blog feed once
#' posted to Slack and then died saving its seen-set, which would have
#' announced the same post again on the next poll. The lasting fix is
#' `req_retry()` in `cloudflarer` itself, which would make this a
#' deletion; the KV wrappers retry in the meantime, and nothing else
#' does.
#'
#' Only retries what retrying can fix - a transport failure, a 429, or a
#' 5xx. A 404 (missing key) or a 403 (wrong token) is returned to the
#' caller on the first attempt, as is anything raised before the request
#' leaves (`cloudflarer`'s own argument checks, a missing account id).
#'
#' The 429 matters more than it looks: Workers KV allows one write per
#' second to the same key, so a caller writing one key repeatedly - see
#' [blog_feed_post()] - earns 429s in normal operation, and the backoff
#' doubles as its throttle. `Retry-After` is ignored; a flat second is
#' enough for a one-per-second limit.
#'
#' @param call Zero-argument function performing the Cloudflare call.
#' @param tries Most attempts to make.
#' @return Whatever `call` returns.
#' @keywords internal
#' @noRd
cf_ops_retry <- function(call, tries = 3L) {
  attempt <- 0L
  repeat {
    attempt <- attempt + 1L
    result <- tryCatch(call(), error = function(e) e)
    if (!inherits(result, "error")) {
      return(result)
    }
    if (attempt >= tries || !cf_ops_transient(result)) {
      stop(result)
    }
    cf_ops_backoff(attempt)
  }
}

#' Wait between Cloudflare retries
#'
#' Its own function, rather than an anonymous one inlined in
#' [cf_ops_retry()], so a test can replace it and assert the retry
#' without waiting for it.
#'
#' @param attempt Attempt number that just failed.
#' @return Nothing, called for the wait.
#' @keywords internal
#' @noRd
cf_ops_backoff <- function(attempt) {
  Sys.sleep(attempt)
}

#' The HTTP status a failed Cloudflare call carries, if any
#'
#' `cloudflarer` attaches the status to its `cloudflarer_error` as
#' `status_code`. A transport failure is an `httr2_failure` and carries
#' none, as does anything raised before the request went out.
#'
#' @param cnd Condition raised by the call.
#' @return The status, or `NULL` when there is no usable one.
#' @keywords internal
#' @noRd
cf_ops_status <- function(cnd) {
  status <- cnd$status_code
  if (length(status) == 1L && !is.na(status)) {
    status
  } else {
    NULL
  }
}

#' Is a failed Cloudflare call worth trying again?
#'
#' @param cnd Condition raised by the call.
#' @return `TRUE` when the failure is transport-level, a 429, or a 5xx.
#' @keywords internal
#' @noRd
cf_ops_transient <- function(cnd) {
  status <- cf_ops_status(cnd)
  if (is.null(status)) {
    return(inherits(cnd, "httr2_failure"))
  }
  status >= 500L || status == 429L
}

#' Did a failed Cloudflare call just mean "no such key"?
#'
#' @param cnd Condition raised by the call.
#' @return `TRUE` for a 404.
#' @keywords internal
#' @noRd
cf_ops_missing_key <- function(cnd) {
  isTRUE(cf_ops_status(cnd) == 404L)
}

#' Read a single value from a Cloudflare KV namespace
#'
#' Read-only, for interactive/console use during an incident — see
#' [cf_ops_list_kv_keys()] for why this isn't wired into a `/jinx` command.
#'
#' @inheritParams cf_ops_list_kv_keys
#' @param key_name Key to read.
#' @return Character string with the stored value.
#' @export
cf_ops_get_kv_value <- function(
  account_id = Sys.getenv("CLOUDFLARE_ACCOUNT_ID"),
  namespace_id,
  key_name,
  token = cf_ops_token()
) {
  cf_ops_retry(function() {
    cloudflarer::cf_get_kv_value(
      account_id = account_id,
      namespace_id = namespace_id,
      key_name = key_name,
      as = "text",
      token = token
    )
  })
}

#' Write a single value to a Cloudflare KV namespace
#'
#' Wraps [cloudflarer::cf_put_kv_value()]. Unlike [cf_ops_list_kv_keys()]/
#' [cf_ops_get_kv_value()], this is not a general-purpose "read/write any
#' key" tool exposed to a `/jinx` command — it's called internally by
#' event/command handlers against a small set of hardcoded key patterns
#' (e.g. `pending_link:{email}`, `channel_index:{team_id}`), the same
#' scoping the exfiltration concern in those two functions' docs warns
#' about.
#'
#' @inheritParams cf_ops_list_kv_keys
#' @param key_name Key to write.
#' @param value Character value to store.
#' @param ttl_seconds Optional expiration TTL in seconds.
#' @return The API response (invisibly).
#' @export
cf_ops_kv_put <- function(
  account_id = Sys.getenv("CLOUDFLARE_ACCOUNT_ID"),
  namespace_id,
  key_name,
  value,
  ttl_seconds = NULL,
  token = cf_ops_token()
) {
  invisible(cf_ops_retry(function() {
    cloudflarer::cf_put_kv_value(
      account_id = account_id,
      namespace_id = namespace_id,
      key_name = key_name,
      value = value,
      expiration_ttl = ttl_seconds,
      token = token
    )
  }))
}

#' Delete a single value from a Cloudflare KV namespace
#'
#' Wraps [cloudflarer::cf_delete_kv_value()]. See [cf_ops_kv_put()] for
#' why this is narrowly scoped rather than a general-purpose tool.
#'
#' @inheritParams cf_ops_list_kv_keys
#' @param key_name Key to delete.
#' @return The API response (invisibly).
#' @export
cf_ops_kv_delete <- function(
  account_id = Sys.getenv("CLOUDFLARE_ACCOUNT_ID"),
  namespace_id,
  key_name,
  token = cf_ops_token()
) {
  invisible(cloudflarer::cf_delete_kv_value(
    account_id = account_id,
    namespace_id = namespace_id,
    key_name = key_name,
    token = token
  ))
}

#' Purge specific URLs or prefixes from the Cloudflare cache
#'
#' Thin wrapper over [cloudflarer::cf_purge_cache()] that deliberately
#' does not expose `purge_everything` — a maintainer who genuinely needs
#' a full-zone wipe calls `cloudflarer::cf_purge_cache(purge_everything =
#' TRUE)` directly. That extra step is intentional friction on the most
#' dangerous call this integration can make.
#'
#' @param zone_id Cloudflare zone ID. Defaults to env `CLOUDFLARE_ZONE_ID`.
#' @param files Optional character vector of URLs to purge.
#' @param prefixes Optional character vector of URL prefixes to purge
#'   (without scheme), e.g. `"rladies.org/blog"`.
#' @param token Cloudflare API token. Defaults to env
#'   `CLOUDFLARE_OPS_API_TOKEN`, falling back to `CLOUDFLARE_API_TOKEN`.
#' @return A named list with the purge job `id`.
#' @export
cf_ops_purge_cache <- function(
  zone_id = Sys.getenv("CLOUDFLARE_ZONE_ID"),
  files = NULL,
  prefixes = NULL,
  token = cf_ops_token()
) {
  if (is.null(files) && is.null(prefixes)) {
    cli::cli_abort(c(
      "Nothing to purge.",
      i = "Supply {.arg files} or {.arg prefixes}."
    ))
  }
  cloudflarer::cf_purge_cache(
    zone_id = zone_id,
    files = files,
    prefixes = prefixes,
    token = token
  )
}

#' Read a JSON string array out of KV
#'
#' Several schedules keep "what have I already done" as a list of ids
#' under one key - the channel spotlight's round-robin, the blog feed's
#' announced posts. An absent key is the first run and reads as nothing
#' recorded, as does a value that is empty or isn't JSON.
#'
#' A read that fails for any other reason aborts instead. "Nothing
#' recorded" and "I could not find out" look identical to the caller but
#' are not: the blog feed answers the first by announcing everything
#' recent, which on a Cloudflare blip would repost up to `limit` posts
#' the channel has already seen.
#'
#' @param key_name KV key holding a JSON array of strings.
#' @param namespace_id KV namespace ID.
#' @param account_id Cloudflare account ID.
#' @param api_token Cloudflare API token.
#' @return Character vector.
#' @keywords internal
#' @noRd
kv_string_set_load <- function(
  key_name,
  namespace_id = slack_tokens_namespace_id(),
  account_id = Sys.getenv("CLOUDFLARE_ACCOUNT_ID"),
  api_token = Sys.getenv("CLOUDFLARE_API_TOKEN")
) {
  raw <- tryCatch(
    cf_ops_get_kv_value(
      account_id = account_id,
      namespace_id = namespace_id,
      key_name = key_name,
      token = api_token
    ),
    cloudflarer_error = function(e) {
      if (!cf_ops_missing_key(e)) {
        stop(e)
      }
      NA_character_
    }
  )
  if (length(raw) != 1L || is.na(raw) || !nzchar(raw)) {
    return(character())
  }
  parsed <- tryCatch(
    jsonlite::fromJSON(raw, simplifyVector = TRUE),
    error = function(e) character()
  )
  as.character(parsed)
}

#' Write a JSON string array to KV
#'
#' @inheritParams kv_string_set_load
#' @param values Character vector to store.
#' @param keep When set, drop duplicates and store only the last `keep`
#'   values, so a growing set cannot outgrow a single KV read.
#' @return The API response (invisibly).
#' @keywords internal
#' @noRd
kv_string_set_save <- function(
  key_name,
  values,
  keep = NULL,
  namespace_id = slack_tokens_namespace_id(),
  account_id = Sys.getenv("CLOUDFLARE_ACCOUNT_ID"),
  api_token = Sys.getenv("CLOUDFLARE_API_TOKEN")
) {
  values <- as.character(values)
  if (!is.null(keep)) {
    values <- utils::tail(unique(values), keep)
  }
  cf_ops_kv_put(
    account_id = account_id,
    namespace_id = namespace_id,
    key_name = key_name,
    value = jsonlite::toJSON(values),
    token = api_token
  )
}
