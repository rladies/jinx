#' Base URL for the samkoma scheduling API
#'
#' Overridable via the `SAMKOMA_BASE_URL` environment variable so tests
#' and staging can point at a different host.
#'
#' @return Character scalar.
#' @keywords internal
#' @noRd
samkoma_base_url <- function() {
  url <- Sys.getenv("SAMKOMA_BASE_URL")
  if (nzchar(url)) url else "https://api.samkoma.org"
}

#' User-Agent string for samkoma API calls
#' @return Character scalar.
#' @keywords internal
#' @noRd
samkoma_user_agent <- function() {
  paste0(
    "rladies-jinx/",
    utils::packageVersion("jinx"),
    " (+https://github.com/rladies/jinx)"
  )
}

#' Build a base samkoma API request
#'
#' Attaches the User-Agent and retry policy. When an `edit_token` is
#' supplied it is sent as a bearer token, which authenticates host-only
#' operations (editing, locking, reading hidden responses).
#'
#' @param edit_token Optional poll edit token returned by
#'   [meeting_poll_create()].
#' @param base_url API base URL.
#' @param user_agent User-Agent header.
#' @return An [httr2::request] object.
#' @keywords internal
#' @noRd
samkoma_request <- function(
  edit_token = NULL,
  base_url = samkoma_base_url(),
  user_agent = samkoma_user_agent()
) {
  req <- httr2::request(base_url) |>
    httr2::req_user_agent(user_agent) |>
    httr2::req_retry(max_tries = 3)
  if (!is.null(edit_token) && nzchar(edit_token)) {
    req <- httr2::req_auth_bearer_token(req, edit_token)
  }
  req
}

#' Perform a samkoma request, surfacing API errors clearly
#'
#' @param req An [httr2::request] object.
#' @return The [httr2::response] object.
#' @keywords internal
#' @noRd
samkoma_perform <- function(req) {
  tryCatch(
    httr2::req_perform(req),
    error = function(cnd) {
      status <- tryCatch(
        httr2::resp_status(cnd$resp),
        error = function(e) NA_integer_
      )
      if (isTRUE(status == 429L)) {
        cli::cli_abort(
          "samkoma rate limit reached - wait a moment and try again.",
          parent = cnd
        )
      }
      detail <- samkoma_error_detail(cnd$resp)
      if (nzchar(detail)) {
        cli::cli_abort("samkoma API request failed: {detail}", parent = cnd)
      }
      cli::cli_abort("samkoma API request failed.", parent = cnd)
    }
  )
}

#' Extract a human-readable detail from a failed samkoma response
#'
#' @param resp An [httr2::response], or `NULL` for a network error.
#' @return A short detail string, or `""` when none is available.
#' @keywords internal
#' @noRd
samkoma_error_detail <- function(resp) {
  if (is.null(resp)) {
    return("")
  }
  body <- tryCatch(httr2::resp_body_string(resp), error = function(e) "")
  if (!nzchar(body)) {
    return("")
  }
  parsed <- tryCatch(
    jsonlite::fromJSON(body, simplifyVector = TRUE),
    error = function(e) NULL
  )
  if (is.list(parsed)) {
    msg <- parsed$message %||% parsed$error %||% parsed$code
    if (!is.null(msg) && nzchar(msg[1])) {
      return(as.character(msg)[1])
    }
  }
  substr(body, 1, 200)
}

#' Regex a poll id must match to be safe to interpolate into a URL path
#' @keywords internal
#' @noRd
samkoma_id_pattern <- function() "^[A-Za-z0-9_-]+$"

#' Validate a poll id before interpolating it into a URL path
#'
#' Poll ids come from untrusted input (issue comments), so they must
#' not be able to manipulate the request URL.
#'
#' @param id The poll id.
#' @return Invisibly, the validated id.
#' @keywords internal
#' @noRd
samkoma_check_id <- function(id) {
  if (
    !is.character(id) ||
      length(id) != 1 ||
      !grepl(samkoma_id_pattern(), id)
  ) {
    cli::cli_abort("{.arg id} must be an alphanumeric poll id.")
  }
  invisible(id)
}

#' Build a request for a poll endpoint, validating the id first
#'
#' @param id Poll id (validated against [samkoma_id_pattern()]).
#' @param ... Extra path segments appended after `v1/polls/{id}`.
#' @param edit_token Optional host edit token.
#' @param base_url API base URL.
#' @return An [httr2::request] object.
#' @keywords internal
#' @noRd
samkoma_poll_request <- function(
  id,
  ...,
  edit_token = NULL,
  base_url = samkoma_base_url()
) {
  samkoma_check_id(id)
  samkoma_request(edit_token = edit_token, base_url = base_url) |>
    httr2::req_url_path_append("v1", "polls", id, ...)
}

#' Create a meeting-scheduling poll on samkoma
#'
#' Creates a "find a time" poll where participants paint their
#' availability over a set of days and time slots. Polls are public by
#' default so results can be read back without a stored secret; the
#' returned `edit_token` is the host secret needed to lock the final
#' slot or read a hidden poll.
#'
#' @param title Poll title (1-200 characters).
#' @param days Character vector of day identifiers: ISO dates
#'   (`YYYY-MM-DD`) when `kind = "dates"`, or weekday names
#'   (`mon`..`sun`) when `kind = "weekdays"`. 1-60 items.
#' @param from,to Start and end of the daily window, `"HH:MM"` (24h).
#' @param slot Slot length in minutes.
#' @param tz IANA timezone name (e.g. `"Europe/Oslo"`). Defaults to UTC.
#' @param kind Either `"dates"` (default) or `"weekdays"`.
#' @param public Whether the poll is publicly readable. Defaults to `TRUE`.
#' @param results_hidden Whether responses are hidden from voters.
#' @param deadline Optional ISO 8601 datetime after which voting closes.
#' @param base_url API base URL.
#' @return A list with `id`, `url`, and `edit_token`.
#' @export
meeting_poll_create <- function(
  title,
  days,
  from,
  to,
  slot,
  tz = "UTC",
  kind = c("dates", "weekdays"),
  public = TRUE,
  results_hidden = FALSE,
  deadline = NULL,
  base_url = samkoma_base_url()
) {
  kind <- match.arg(kind)
  slot <- suppressWarnings(as.integer(slot))
  samkoma_validate_poll_title(title)
  samkoma_validate_poll_window(days, from, to, slot, tz)

  body <- list(
    title = title,
    kind = kind,
    days = as.list(days),
    from = from,
    to = to,
    slot = slot,
    tz = tz,
    public = public,
    resultsHidden = results_hidden
  )
  if (!is.null(deadline)) {
    body$deadline <- deadline
  }

  req <- samkoma_request(base_url = base_url) |>
    httr2::req_url_path_append("v1", "polls") |>
    httr2::req_body_json(body)

  out <- httr2::resp_body_json(samkoma_perform(req))
  list(id = out$id, url = out$url, edit_token = out$editToken)
}

#' @keywords internal
#' @noRd
samkoma_validate_poll_title <- function(title) {
  if (!is.character(title) || length(title) != 1 || !nzchar(trimws(title))) {
    cli::cli_abort("{.arg title} must be a non-empty string.")
  }
  if (nchar(title) > 200) {
    cli::cli_abort("{.arg title} must be at most 200 characters.")
  }
}

#' @keywords internal
#' @noRd
samkoma_validate_poll_window <- function(days, from, to, slot, tz) {
  if (length(days) < 1 || length(days) > 60) {
    cli::cli_abort("{.arg days} must have between 1 and 60 items.")
  }
  if (!samkoma_is_time(from) || !samkoma_is_time(to)) {
    cli::cli_abort("{.arg from} and {.arg to} must be in HH:MM format.")
  }
  if (is.na(slot) || slot <= 0L) {
    cli::cli_abort("{.arg slot} must be a positive number of minutes.")
  }
  if (!nzchar(tz)) {
    cli::cli_abort("{.arg tz} must be a non-empty timezone name.")
  }
}

#' Fetch a poll and its aggregated responses
#'
#' @param id Poll id.
#' @param edit_token Optional host edit token, required to read a hidden
#'   poll's responses.
#' @param base_url API base URL.
#' @return Parsed poll object as a list.
#' @export
meeting_poll_get <- function(
  id,
  edit_token = NULL,
  base_url = samkoma_base_url()
) {
  req <- samkoma_poll_request(id, edit_token = edit_token, base_url = base_url)
  httr2::resp_body_json(samkoma_perform(req))
}

#' Get the ranked best slots for a poll
#'
#' @inheritParams meeting_poll_get
#' @return A data frame with columns `slot`, `count`, and `names`
#'   (comma-separated), ordered best-first. The total number of
#'   respondents is attached as the `total` attribute.
#' @export
meeting_poll_best <- function(
  id,
  edit_token = NULL,
  base_url = samkoma_base_url()
) {
  req <- samkoma_poll_request(
    id,
    "best",
    edit_token = edit_token,
    base_url = base_url
  )
  out <- httr2::resp_body_json(samkoma_perform(req))

  results <- out$results %||% list()
  if (length(results) == 0) {
    df <- meeting_poll_best_empty()
  } else {
    df <- do.call(rbind, lapply(results, meeting_poll_best_row))
  }
  attr(df, "total") <- as.integer(out$total %||% 0L)
  df
}

#' Lock in (or clear) the chosen slot for a poll
#'
#' Host-only: requires the poll's `edit_token`.
#'
#' @inheritParams meeting_poll_get
#' @param slot The chosen slot identifier (`YYYY-MM-DDTHH:MM` or
#'   `[mon-sun]THH:MM`), or `NULL` to clear a previously locked slot.
#' @return Invisibly, the parsed response.
#' @export
meeting_poll_lock <- function(
  id,
  slot,
  edit_token,
  base_url = samkoma_base_url()
) {
  if (missing(edit_token) || is.null(edit_token) || !nzchar(edit_token)) {
    cli::cli_abort("Locking a slot requires the poll's {.arg edit_token}.")
  }
  req <- samkoma_poll_request(
    id,
    "lock",
    edit_token = edit_token,
    base_url = base_url
  ) |>
    httr2::req_body_json(list(slot = slot))
  invisible(httr2::resp_body_json(samkoma_perform(req)))
}

#' Export the locked slot of a poll as an iCalendar (.ics) string
#'
#' @inheritParams meeting_poll_get
#' @return The .ics file contents as a character string.
#' @export
meeting_poll_ics <- function(id, base_url = samkoma_base_url()) {
  req <- samkoma_poll_request(id, "ics", base_url = base_url)
  httr2::resp_body_string(samkoma_perform(req))
}

#' Neutralise markdown control characters in externally-sourced text
#'
#' Poll titles and participant names come from the samkoma API and are
#' rendered into messages authored by the bot on GitHub and Slack. The
#' two renderers escape differently, so this:
#' - collapses newlines (blocks heading/list/blockquote injection),
#' - HTML-entity-encodes `&`, `<`, `>` (neutralises Slack `<url|text>`
#'   links, GitHub autolinks, and raw HTML; both renderers display the
#'   entities as the literal characters),
#' - backslash-escapes `[`, `]`, and backticks, which is enough to break
#'   `[text](url)` / `![](img)` link and image injection and code-span
#'   breakout without uglifying common punctuation (parentheses, `!`)
#'   that Slack would render with a literal backslash.
#'
#' @param x Character scalar.
#' @return The neutralised string.
#' @keywords internal
#' @noRd
samkoma_escape_md <- function(x) {
  if (!is.character(x) || length(x) == 0) {
    return(x)
  }
  x <- gsub("[\r\n]+", " ", x)
  x <- gsub("&", "&amp;", x, fixed = TRUE)
  x <- gsub("<", "&lt;", x, fixed = TRUE)
  x <- gsub(">", "&gt;", x, fixed = TRUE)
  specials <- c("\\", "`", "[", "]")
  for (ch in specials) {
    x <- gsub(ch, paste0("\\", ch), x, fixed = TRUE)
  }
  x
}

#' Format a created poll as a markdown announcement
#'
#' Deliberately omits the edit token, which is a host secret.
#'
#' @param created A list returned by [meeting_poll_create()].
#' @param title The poll title.
#' @return Character string of markdown.
#' @export
meeting_poll_format_created <- function(created, title) {
  glue::glue(
    "\U0001f4c5 **Meeting poll created: {samkoma_escape_md(title)}**\n\n",
    "Paint when you're free here: {created$url}\n\n",
    "_Once everyone has voted, run `/jinx poll best {created$id}`",
    " to see the top slots._"
  )
}

#' Format ranked best slots as markdown
#'
#' @param best A data frame from [meeting_poll_best()].
#' @param title Optional poll title for the heading.
#' @param top Maximum number of slots to show.
#' @return Character string of markdown.
#' @export
meeting_poll_format_best <- function(best, title = NULL, top = 3) {
  heading <- if (is.null(title)) {
    "## Best meeting times"
  } else {
    glue::glue("## Best meeting times: {samkoma_escape_md(title)}")
  }
  if (nrow(best) == 0) {
    return(paste0(heading, "\n\n_No availability submitted yet._"))
  }
  total <- attr(best, "total") %||% 0L
  n <- min(top, nrow(best))
  rows <- best[seq_len(n), , drop = FALSE]
  rows$slot <- samkoma_escape_md(rows$slot)
  rows$names <- samkoma_escape_md(rows$names)
  lines <- vapply(
    seq_len(nrow(rows)),
    function(i) {
      r <- rows[i, ]
      who <- if (nzchar(r$names)) glue::glue(" ({r$names})") else ""
      avail <- if (total > 0) {
        glue::glue("{r$count}/{total} available")
      } else {
        glue::glue("{r$count} available")
      }
      glue::glue("{i}. **{r$slot}** - {avail}{who}")
    },
    character(1)
  )
  paste0(heading, "\n\n", paste(lines, collapse = "\n"))
}

#' @keywords internal
#' @noRd
samkoma_is_time <- function(x) {
  is.character(x) && length(x) == 1 && grepl("^\\d{2}:\\d{2}$", x)
}

#' @keywords internal
#' @noRd
meeting_poll_best_row <- function(result) {
  data.frame(
    slot = result$slot %||% NA_character_,
    count = as.integer(result$count %||% 0L),
    names = paste(unlist(result$names %||% list()), collapse = ", "),
    stringsAsFactors = FALSE
  )
}

#' @keywords internal
#' @noRd
meeting_poll_best_empty <- function() {
  data.frame(
    slot = character(0),
    count = integer(0),
    names = character(0),
    stringsAsFactors = FALSE
  )
}
