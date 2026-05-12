#' Format a goodpractice result as a GitHub PR comment
#'
#' Walks failing checks in a `goodpractice` result and produces a
#' markdown report listing each failed check, a short description, and
#' up to `max_positions` source locations per check. Strips ANSI codes
#' and truncates to `max_chars` to fit within GitHub's PR comment limit.
#'
#' @param gp_result Object returned by [goodpractice::gp()].
#' @param max_positions Maximum number of failure positions shown per
#'   check. Defaults to 5.
#' @param max_chars Soft character ceiling for the report. Output past
#'   this is truncated with a marker. Defaults to 60000.
#' @return Character scalar — a markdown-formatted report.
#' @keywords internal
format_goodpractice_report <- function(
  gp_result,
  max_positions = 5L,
  max_chars = 60000L
) {
  failing <- failing_check_names(gp_result)

  if (length(failing) == 0) {
    return("\U0001f389 **Good Practice Check**\n\nAll checks passed!")
  }

  positions <- tryCatch(
    goodpractice::failed_positions(gp_result),
    error = function(e) list()
  )

  blocks <- vapply(
    failing,
    function(name) gp_failure_block(name, positions[[name]], max_positions),
    character(1)
  )

  body <- paste0(
    "\U0001f50d **Good Practice Check**\n\n",
    "Found ",
    length(failing),
    " failing check(s):\n\n",
    paste(blocks, collapse = "\n\n")
  )

  body <- strip_ansi(body)

  if (nchar(body) > max_chars) {
    body <- paste0(
      substr(body, 1, max_chars),
      "\n\n_(output truncated to fit GitHub comment limit)_"
    )
  }

  body
}

failing_check_names <- function(gp_result) {
  tryCatch(
    {
      failing <- goodpractice::failed_checks(gp_result)
      if (is.character(failing)) failing else names(failing)
    },
    error = function(e) {
      statuses <- vapply(
        gp_result$checks,
        function(chk) {
          if (is.list(chk)) isTRUE(chk$status) else isTRUE(chk)
        },
        logical(1)
      )
      names(gp_result$checks)[!statuses]
    }
  )
}

gp_failure_block <- function(name, positions, max_positions) {
  desc <- tryCatch(
    {
      d <- goodpractice::describe_check(name)
      if (length(d) >= 1 && nzchar(d[[1]])) d[[1]] else ""
    },
    error = function(e) ""
  )

  header <- paste0(
    "- **",
    name,
    "**",
    if (nzchar(desc)) paste0(": ", desc) else ""
  )

  if (length(positions) == 0) {
    return(header)
  }

  shown <- positions[seq_len(min(length(positions), max_positions))]
  more <- length(positions) - length(shown)

  detail_lines <- vapply(
    shown,
    function(p) {
      file <- p$filename %||% "(unknown)"
      line <- p$line_number %||% "?"
      sprintf("  - `%s:%s`", file, line)
    },
    character(1)
  )

  out <- paste(c(header, detail_lines), collapse = "\n")

  if (more > 0) {
    out <- paste0(out, "\n  - _… ", more, " more_")
  }

  out
}

strip_ansi <- function(x) {
  gsub("\033\\[[0-9;]*m", "", x)
}
