checks <- c(
  "cyclocomp",
  "no_description_depends",
  "no_import_package_as_a_whole",
  "lintr_assignment_linter",
  "lintr_line_length_linter"
)

gp_result <- goodpractice::gp(".", checks = checks)

failing <- tryCatch(
  {
    f <- goodpractice::failed_checks(gp_result)
    if (is.character(f)) f else names(f)
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

strip_ansi <- function(x) gsub("\033\\[[0-9;]*m", "", x)

if (length(failing) == 0) {
  body <- "\U0001f389 **Good Practice Check**\n\nAll checks passed!"
} else {
  positions <- tryCatch(
    goodpractice::failed_positions(gp_result),
    error = function(e) list()
  )
  max_positions <- 5L

  blocks <- vapply(
    failing,
    function(name) {
      desc <- tryCatch(
        goodpractice::describe_check(name)[[1]] %||% "",
        error = function(e) ""
      )

      header <- paste0(
        "- **",
        name,
        "**",
        if (nzchar(desc)) paste0(": ", desc) else ""
      )

      pos <- positions[[name]]
      if (length(pos) == 0) {
        return(header)
      }

      shown <- pos[seq_len(min(length(pos), max_positions))]
      more <- length(pos) - length(shown)

      detail <- vapply(
        shown,
        function(p) {
          sprintf(
            "  - `%s:%s`",
            p$filename %||% "(unknown)",
            p$line_number %||% "?"
          )
        },
        character(1)
      )

      out <- paste(c(header, detail), collapse = "\n")
      if (more > 0) paste0(out, "\n  - _… ", more, " more_") else out
    },
    character(1)
  )

  body <- paste0(
    "\U0001f50d **Good Practice Check**\n\n",
    "Found ",
    length(failing),
    " failing check(s):\n\n",
    paste(blocks, collapse = "\n\n")
  )
}

body <- strip_ansi(body)

max_chars <- 60000L
if (nchar(body) > max_chars) {
  body <- paste0(
    substr(body, 1, max_chars),
    "\n\n_(output truncated to fit GitHub comment limit)_"
  )
}

writeLines(body, "gp_report.md")

quit(status = if (length(failing) > 0) 1 else 0)
