cf_error <- function(status) {
  cli::cli_abort(
    "Cloudflare API request failed.",
    class = "cloudflarer_error",
    status_code = status
  )
}

transport_error <- function() {
  cli::cli_abort(
    "Failed to perform HTTP request.",
    class = c("httr2_failure", "httr2_error")
  )
}
