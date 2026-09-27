#' Reconcile stored chapter status against actual Meetup activity
#'
#' The website's `status` field is set by hand, so it drifts from what
#' the chapters are actually doing. This compares it against the event
#' history in `meetup_archive` and reports the two mismatches worth
#' acting on: a chapter running events that is not marked active, and a
#' chapter marked active that has gone quiet.
#'
#' The categories follow the guide: a chapter is active when it has run
#' an event in the last `months`, and inactive when it has not.
#'
#' Chapters create their events on Meetup even when they promote them
#' elsewhere, precisely so activity can be tracked, so an absence of
#' Meetup events is a real signal rather than an artefact of where a
#' chapter advertises. That holds for every chapter, so one with no
#' Meetup group at all is included here rather than skipped: having no
#' group means it never began, or stopped before it started.
#'
#' @param chapters_dir Directory of chapter JSON files, typically
#'   `data/chapters` in the website repository.
#' @param health Output of [chapter_check_health()], or `NULL` to fetch
#'   it. Passed in to avoid refetching when reconciling repeatedly.
#' @param months Months without an event before a chapter is flagged.
#'   Defaults to 6, matching the guide.
#' @param retire_months Months without an event before a chapter should
#'   simply be marked inactive. Defaults to 12.
#' @param initiated Optional `Date` vector, one per file in
#'   `chapters_dir`, from [chapter_initiated_date()]. A chapter younger
#'   than `retire_months` is never marked inactive, because it has not
#'   had time to run anything yet. `NA` counts as old enough.
#' @return A data frame with one row per chapter that has a `urlname`,
#' @return A data frame with one row per chapter, with columns `file`,
#'   `urlname`, `stored`, `last_event`, `months_inactive` and `action`.
#'   `action` is `"promote to active"`, `"flag quiet"`,
#'   `"mark inactive"`, or `NA` when nothing needs doing.
#' @export
chapter_status_reconcile <- function(
  chapters_dir,
  health = NULL,
  months = 6,
  retire_months = 12,
  initiated = NULL
) {
  if (is.null(health)) {
    health <- chapter_check_health(months = months)
  }
  stored <- chapter_stored_status(chapters_dir)
  if (nrow(stored) == 0) {
    return(chapter_reconcile_frame())
  }

  idx <- match(tolower(stored$urlname), tolower(health$chapter))
  stored$last_event <- as.Date(NA)
  stored$months_inactive <- NA_integer_
  found <- !is.na(idx)
  stored$last_event[found] <- as.Date(health$last_event[idx[found]])
  stored$months_inactive[found] <- health$months_inactive[idx[found]]

  stored$age_months <- chapter_age_months(initiated, stored$row)

  stored$action <- mapply(
    chapter_reconcile_action,
    stored$stored,
    stored$months_inactive,
    stored$age_months,
    MoreArgs = list(months = months, retire_months = retire_months),
    USE.NAMES = FALSE
  )
  stored$row <- NULL
  stored$age_months <- NULL
  rownames(stored) <- NULL
  stored
}

chapter_reconcile_frame <- function() {
  data.frame(
    file = character(),
    urlname = character(),
    stored = character(),
    last_event = as.Date(character()),
    months_inactive = integer(),
    action = character(),
    stringsAsFactors = FALSE
  )
}

chapter_reconcile_action <- function(
  stored,
  months_inactive,
  age_months,
  months,
  retire_months
) {
  if (isTRUE(!is.na(months_inactive) && months_inactive < months)) {
    return(chapter_active_action(stored))
  }
  # Being closed is a deliberate end state, so silence is expected and
  # not worth reporting. Coming back to life above still is.
  if (isTRUE(startsWith(stored %||% "", "retired"))) {
    return(NA_character_)
  }
  if (isTRUE(is.na(months_inactive) || months_inactive >= retire_months)) {
    return(chapter_dormant_action(stored, age_months, retire_months))
  }
  "flag quiet"
}

chapter_active_action <- function(stored) {
  if (identical(stored, "active")) {
    return(NA_character_)
  }
  "promote to active"
}

chapter_dormant_action <- function(stored, age_months, retire_months) {
  too_young <- isTRUE(!is.na(age_months) && age_months < retire_months)
  if (too_young || identical(stored, "inactive")) {
    return(NA_character_)
  }
  "mark inactive"
}

chapter_age_months <- function(initiated, rows) {
  if (is.null(initiated)) {
    return(rep(NA_real_, length(rows)))
  }
  picked <- initiated[rows]
  as.numeric(difftime(Sys.Date(), picked, units = "days")) / 30
}

chapter_stored_status <- function(chapters_dir) {
  files <- list.files(chapters_dir, pattern = "[.]json$", full.names = TRUE)
  rows <- lapply(seq_along(files), function(i) {
    f <- files[[i]]
    chapter <- tryCatch(jsonlite::read_json(f), error = function(e) NULL)
    if (is.null(chapter)) {
      return(NULL)
    }
    urlname <- chapter$urlname %||% NA_character_
    data.frame(
      file = basename(f),
      urlname = if (nzchar(urlname %||% "")) urlname else NA_character_,
      stored = chapter$status %||% NA_character_,
      row = i,
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, rows)
  if (is.null(out)) data.frame() else out
}

#' Render a status reconciliation as markdown
#'
#' @param reconciled Data frame from [chapter_status_reconcile()].
#' @param months Months used for the inactivity window, for the wording.
#' @return A markdown string.
#' @export
chapter_status_reconcile_report <- function(reconciled, months = 6) {
  todo <- reconciled[!is.na(reconciled$action), , drop = FALSE]
  header <- "## Chapter status reconciliation\n\n"
  if (nrow(todo) == 0) {
    return(paste0(header, "Every chapter's status matches its activity.\n"))
  }

  promote <- todo[todo$action == "promote to active", , drop = FALSE]
  quiet <- todo[todo$action == "flag quiet", , drop = FALSE]
  retire <- todo[todo$action == "mark inactive", , drop = FALSE]

  paste0(
    header,
    chapter_reconcile_section(
      promote,
      paste0("Running events but not marked active (", nrow(promote), ")"),
      "last event"
    ),
    chapter_reconcile_section(
      quiet,
      paste0("No Meetup event in ", months, " months (", nrow(quiet), ")"),
      "last event"
    ),
    chapter_reconcile_section(
      retire,
      paste0("Mark inactive, nothing for a year or more (", nrow(retire), ")"),
      "last event"
    ),
    chapter_reconcile_caveat(nrow(quiet) + nrow(retire)),
    "\n_Generated by jinx_\n"
  )
}

chapter_reconcile_caveat <- function(n_flagged) {
  if (n_flagged == 0) {
    return("")
  }
  paste0(
    "> Chapters are asked to create events on Meetup even when they ",
    "advertise elsewhere, so an absent event is a real gap. Check ",
    "before changing a status: an organiser may have run something ",
    "without posting it.\n\n"
  )
}

chapter_reconcile_section <- function(rows, title, label) {
  if (nrow(rows) == 0) {
    return("")
  }
  when <- ifelse(
    is.na(rows$last_event),
    "no events on record",
    paste(label, rows$last_event)
  )
  lines <- paste0(
    "- `",
    rows$file,
    "` (",
    rows$stored,
    "): ",
    when
  )
  paste0("### ", title, "\n\n", paste(lines, collapse = "\n"), "\n\n")
}

#' When a chapter first appeared in the website repository
#'
#' Used as the start of the six-month window in which a chapter with no
#' events counts as unbegun rather than inactive.
#'
#' Two things make this fragile, and both are handled here. Renaming a
#' chapter file would otherwise reset its date to the rename, so the
#' lookup follows renames. A shallow clone has no history to read, so
#' the caller's checkout needs `fetch-depth: 0`; without it every
#' chapter looks as though it appeared today.
#'
#' Dates before `bulk_import` are not meaningful: 118 chapters were
#' added to the website in one import on 2023-01-04, so that date
#' records the import rather than when any of those chapters started.
#' Those come back as `NA`.
#'
#' @param files Chapter file paths, relative to `repo`.
#' @param repo Path to the website repository.
#' @param bulk_import Date of the bulk import to treat as unknown, or
#'   `NULL` to keep every date.
#' @return A `Date` vector, `NA` where the date is unknown or untrusted.
#' @export
chapter_initiated_date <- function(
  files,
  repo = ".",
  bulk_import = as.Date("2023-01-04")
) {
  dates <- vapply(
    files,
    function(f) {
      out <- tryCatch(
        suppressWarnings(system2(
          "git",
          c(
            "-C",
            shQuote(repo),
            "log",
            "--diff-filter=A",
            "--follow",
            "--format=%cs",
            "-1",
            "--",
            shQuote(f)
          ),
          stdout = TRUE,
          stderr = FALSE
        )),
        error = function(e) character()
      )
      if (length(out) == 0) NA_character_ else out[length(out)]
    },
    character(1),
    USE.NAMES = FALSE
  )

  dates <- as.Date(dates)
  if (!is.null(bulk_import)) {
    dates[!is.na(dates) & dates <= bulk_import] <- as.Date(NA)
  }
  dates
}
