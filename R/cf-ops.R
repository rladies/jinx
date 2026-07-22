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
  cloudflarer::cf_get_kv_value(
    account_id = account_id,
    namespace_id = namespace_id,
    key_name = key_name,
    as = "text",
    token = token
  )
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
  invisible(cloudflarer::cf_put_kv_value(
    account_id = account_id,
    namespace_id = namespace_id,
    key_name = key_name,
    value = value,
    expiration_ttl = ttl_seconds,
    token = token
  ))
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
