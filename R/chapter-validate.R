#' Validate website chapter data files
#'
#' Runs the checks that keep `data/chapters/*.json` on the website
#' consistent with the conventions jinx relies on elsewhere: the schema,
#' the filename derivation, and the agreement between `urlname` and
#' `social_media$meetup`.
#'
#' Designed to run over the files changed in a pull request, so that
#' pre-existing drift in untouched files does not block unrelated work.
#'
#' @param paths Character vector of paths to chapter JSON files.
#' @param added Character vector of paths (a subset of `paths`) that the
#'   pull request adds rather than modifies. Filename mismatches are
#'   errors for added files and warnings for modified ones, because 32
#'   files already in the repository predate the convention.
#' @return A data frame with columns `file`, `level` (`"error"` or
#'   `"warning"`), `check`, and `message`. Zero rows when everything
#'   passes.
#' @export
chapter_validate_files <- function(paths, added = character()) {
  issues <- lapply(paths, function(path) {
    chapter_validate_one(path, is_added = path %in% added)
  })
  out <- do.call(rbind, c(list(chapter_issue_frame()), issues))
  rownames(out) <- NULL
  out
}

chapter_issue_frame <- function(
  file = character(),
  level = character(),
  check = character(),
  message = character()
) {
  data.frame(
    file = file,
    level = level,
    check = check,
    message = message,
    stringsAsFactors = FALSE
  )
}

chapter_validate_one <- function(path, is_added = FALSE) {
  raw <- tryCatch(readLines(path, warn = FALSE), error = function(e) NULL)
  if (is.null(raw)) {
    return(chapter_issue_frame(
      basename(path),
      "error",
      "readable",
      "File could not be read"
    ))
  }

  chapter <- tryCatch(
    jsonlite::read_json(path),
    error = function(e) NULL
  )
  if (is.null(chapter)) {
    return(chapter_issue_frame(
      basename(path),
      "error",
      "parse",
      "File is not valid JSON"
    ))
  }

  mojibake <- chapter_check_mojibake(path, raw)

  rbind(
    chapter_check_schema(path, chapter),
    mojibake,
    # The expected filename is derived from the city, region and
    # country, so corrupt text there would have us advise renaming the
    # file to match the corruption. Report the encoding on its own.
    if (is.null(mojibake)) chapter_check_filename(path, chapter, is_added),
    chapter_check_urlname(path, chapter),
    chapter_check_status(path, chapter)
  )
}

chapter_check_schema <- function(path, chapter) {
  schema <- system.file("schemas", "chapter.json", package = "jinx")
  if (!nzchar(schema)) {
    cli::cli_abort("Chapter schema not found in jinx package")
  }
  valid <- jsonvalidate::json_validate(
    jsonlite::toJSON(chapter, auto_unbox = TRUE),
    schema,
    verbose = TRUE
  )
  if (isTRUE(valid)) {
    return(NULL)
  }
  chapter_issue_frame(
    basename(path),
    "error",
    "schema",
    paste(attr(valid, "errors")$message, collapse = "; ")
  )
}

# R renders a byte it cannot decode as "<e1>". Those placeholders have
# been written back into the data files by earlier tooling, so "Ceara"
# is stored as the seven literal characters "Cear<e1>".
chapter_check_mojibake <- function(path, raw) {
  hits <- regmatches(raw, gregexpr("<[0-9a-f]{2}>", raw))
  hits <- unique(unlist(hits))
  if (length(hits) == 0) {
    return(NULL)
  }
  chapter_issue_frame(
    basename(path),
    "error",
    "encoding",
    paste0(
      "Contains escaped byte placeholders (",
      paste(hits, collapse = ", "),
      ") instead of the accented characters they stand for"
    )
  )
}

chapter_check_filename <- function(path, chapter, is_added) {
  expected <- chapter_filename(
    chapter$city,
    chapter$country,
    chapter[["state.region"]]
  )
  if (identical(expected, basename(path))) {
    return(NULL)
  }
  chapter_issue_frame(
    basename(path),
    if (is_added) "error" else "warning",
    "filename",
    paste0("Expected ", expected, " for this city, region and country")
  )
}

chapter_check_urlname <- function(path, chapter) {
  meetup <- chapter$social_media$meetup
  if (is.null(chapter$urlname) || is.null(meetup)) {
    return(NULL)
  }
  if (identical(chapter$urlname, meetup)) {
    return(NULL)
  }
  chapter_issue_frame(
    basename(path),
    "warning",
    "urlname",
    paste0(
      "urlname is '",
      chapter$urlname,
      "' but social_media.meetup is '",
      meetup,
      "'"
    )
  )
}

chapter_check_status <- function(path, chapter) {
  status <- chapter$status
  known <- c("active", "prospective")
  retired <- grepl("^retired on [0-9]{2}-[0-9]{2}-[0-9]{4}$", status)
  if (status %in% known || retired) {
    return(NULL)
  }
  chapter_issue_frame(
    basename(path),
    "warning",
    "status",
    paste0(
      "Unrecognised status '",
      status,
      "'; expected active, prospective, or 'retired on DD-MM-YYYY'"
    )
  )
}

#' Render chapter validation issues as markdown
#'
#' @param issues Data frame returned by [chapter_validate_files()].
#' @param n_files Number of files that were checked.
#' @return A markdown string suitable for a pull request comment.
#' @export
chapter_validate_report <- function(issues, n_files = NA_integer_) {
  header <- "## Chapter data check\n\n"
  if (nrow(issues) == 0) {
    return(paste0(
      header,
      ":white_check_mark: ",
      chapter_file_count(n_files),
      " look good.\n"
    ))
  }

  errors <- issues[issues$level == "error", , drop = FALSE]
  warnings <- issues[issues$level == "warning", , drop = FALSE]

  paste0(
    header,
    chapter_validate_section(errors, "Must fix", ":x:"),
    chapter_validate_section(warnings, "Worth a look", ":warning:"),
    "\n_Generated by jinx_\n"
  )
}

chapter_file_count <- function(n) {
  if (is.na(n)) {
    return("The changed chapter files")
  }
  paste0(n, if (n == 1) " chapter file" else " chapter files")
}

chapter_validate_section <- function(rows, title, icon) {
  if (nrow(rows) == 0) {
    return("")
  }
  lines <- paste0(
    "- ",
    icon,
    " `",
    rows$file,
    "` (",
    rows$check,
    "): ",
    rows$message
  )
  paste0("### ", title, "\n\n", paste(lines, collapse = "\n"), "\n\n")
}
