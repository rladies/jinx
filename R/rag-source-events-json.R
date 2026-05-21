EVENTS_PAST_WINDOW_SECONDS <- 365L * 24L * 60L * 60L
EVENTS_MIN_CHARS <- 80L

#' Gather chunks from a meetup events JSON feed
#'
#' Reads an array of meetup events, drops cancelled events and past
#' events older than one year, and emits one chunk per remaining event.
#' Required `src` fields: `url`, `repo`.
#'
#' @param src Source spec list.
#' @return List of chunk records.
#' @keywords internal
gather_events_json <- function(src) {
  events <- rag_fetch_json(src$url)
  if (!is.list(events) || length(events) == 0L) {
    cli::cli_alert_warning("events-json: no array at {src$url}")
    return(list())
  }

  now <- as.integer(Sys.time())
  cutoff <- now - EVENTS_PAST_WINDOW_SECONDS
  out <- list()

  for (ev in events) {
    if (identical(ev$status, "cancelled")) {
      next
    }
    ts <- rag_parse_date(ev$datetime_utc %||% ev$datetime)
    if (identical(ev$status, "past") && ts > 0L && ts < cutoff) {
      next
    }

    text <- format_event(ev)
    if (nchar(text) < EVENTS_MIN_CHARS) {
      next
    }

    id <- as.character(
      ev$id %||% ev$link %||% paste0(ev$group_urlname, "-", ts)
    )
    out[[length(out) + 1L]] <- list(
      text = text,
      heading = ev$group_name %||% "",
      title = ev$title %||% "Untitled event",
      repo = src$repo,
      path = paste0("event/", id),
      url = ev$link,
      date = ts,
      lastmod = ts,
      chunk_idx = 0L
    )
  }
  cli::cli_alert_info("events-json: {length(out)} chunks")
  out
}

format_event <- function(ev) {
  lines <- character()
  if (!is.null(ev$title)) {
    lines <- c(lines, paste0("Title: ", ev$title))
  }
  if (!is.null(ev$group_name)) {
    lines <- c(lines, paste0("Chapter: ", ev$group_name))
  }
  when <- ev$datetime %||% ev$datetime_utc
  if (!is.null(when)) {
    lines <- c(lines, paste0("When: ", when))
  }
  if (!is.null(ev$status)) {
    status_label <- if (identical(ev$status, "active")) "upcoming" else "past"
    lines <- c(lines, paste0("Status: ", status_label))
  }
  where <- format_event_venue(ev)
  if (nzchar(where)) {
    lines <- c(lines, paste0("Where: ", where))
  }
  if (!is.null(ev$going)) {
    lines <- c(lines, paste0("Attendance: ", ev$going))
  }
  if (!is.null(ev$description) && nzchar(ev$description)) {
    lines <- c(lines, "", trimws(strip_html(ev$description)))
  }
  paste(lines, collapse = "\n")
}

format_event_venue <- function(ev) {
  parts <- c(ev$venue_name, ev$venue_address, ev$venue_city, ev$venue_country)
  parts <- parts[!vapply(parts, is.null, logical(1))]
  if (length(parts) == 0L) {
    return(ev$location %||% "")
  }
  paste(parts, collapse = ", ")
}

strip_html <- function(s) {
  s <- gsub("<[^>]+>", " ", s)
  trimws(gsub("\\s+", " ", s))
}
