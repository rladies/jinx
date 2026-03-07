#' Validate translations for placeholder consistency
#'
#' Checks that all translated templates have the same `<KEY>` placeholders
#' as the English baseline.
#'
#' @param language Language code to validate. If `NULL`, validates all.
#' @return Data frame with columns: template, language, status,
#'   missing_keys, extra_keys.
#' @export
validate_translations <- function(language = NULL) {
  config <- load_languages_config()
  languages <- if (!is.null(language)) {
    language
  } else {
    vapply(config$supported, function(l) l$code, character(1))
  }

  languages <- setdiff(languages, "en")

  base_dir <- system.file("translations", "en", package = "jinx")
  if (!nzchar(base_dir)) {
    base_dir <- system.file("templates", package = "jinx")
  }

  base_templates <- list.files(base_dir, pattern = "\\.md$")
  if (length(base_templates) == 0) {
    return(data.frame(
      template = character(0), language = character(0),
      status = character(0), missing_keys = character(0),
      extra_keys = character(0), stringsAsFactors = FALSE
    ))
  }

  results <- list()

  for (lang in languages) {
    for (tmpl in base_templates) {
      base_path <- file.path(base_dir, tmpl)
      trans_path <- system.file("translations", lang, tmpl, package = "jinx")

      if (!nzchar(trans_path)) {
        results[[length(results) + 1]] <- data.frame(
          template = tmpl, language = lang,
          status = "missing", missing_keys = "", extra_keys = "",
          stringsAsFactors = FALSE
        )
        next
      }

      base_keys <- extract_placeholder_keys(base_path)
      trans_keys <- extract_placeholder_keys(trans_path)

      missing <- setdiff(base_keys, trans_keys)
      extra <- setdiff(trans_keys, base_keys)

      status <- if (length(missing) == 0 && length(extra) == 0) {
        "ok"
      } else {
        "mismatch"
      }

      results[[length(results) + 1]] <- data.frame(
        template = tmpl, language = lang,
        status = status,
        missing_keys = paste(missing, collapse = ", "),
        extra_keys = paste(extra, collapse = ", "),
        stringsAsFactors = FALSE
      )
    }
  }

  if (length(results) == 0) {
    return(data.frame(
      template = character(0), language = character(0),
      status = character(0), missing_keys = character(0),
      extra_keys = character(0), stringsAsFactors = FALSE
    ))
  }

  do.call(rbind, results)
}

#' Check translation coverage across languages
#'
#' @return Data frame with columns: language, total_templates, translated,
#'   coverage_pct.
#' @export
check_translation_coverage <- function() {
  config <- load_languages_config()
  languages <- vapply(config$supported, function(l) l$code, character(1))
  languages <- setdiff(languages, "en")

  base_dir <- system.file("translations", "en", package = "jinx")
  if (!nzchar(base_dir)) {
    base_dir <- system.file("templates", package = "jinx")
  }

  total <- length(list.files(base_dir, pattern = "\\.md$"))

  rows <- lapply(languages, function(lang) {
    trans_dir <- system.file("translations", lang, package = "jinx")
    translated <- if (nzchar(trans_dir)) {
      length(list.files(trans_dir, pattern = "\\.md$"))
    } else {
      0L
    }

    data.frame(
      language = lang,
      total_templates = total,
      translated = translated,
      coverage_pct = if (total > 0) round(translated / total * 100, 1) else 0,
      stringsAsFactors = FALSE
    )
  })

  do.call(rbind, rows)
}

extract_placeholder_keys <- function(path) {
  content <- paste(readLines(path, warn = FALSE), collapse = "\n")
  matches <- gregexpr("<([A-Z_]+)>", content, perl = TRUE)
  keys <- regmatches(content, matches)[[1]]
  unique(gsub("[<>]", "", keys))
}
