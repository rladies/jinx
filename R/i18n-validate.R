#' Validate translations for placeholder consistency
#'
#' Checks that all translated templates have the same `<KEY>` placeholders
#' as the English baseline.
#'
#' @param language Language code to validate. If `NULL`, validates all.
#' @return Data frame with columns: template, language, status,
#'   missing_keys, extra_keys.
#' @export
i18n_translations_validate <- function(language = NULL) {
  languages <- i18n_languages(language)
  base_dir <- i18n_base_dir()
  base_templates <- list.files(base_dir, pattern = "\\.md$")

  if (length(base_templates) == 0) {
    return(i18n_empty_validation_df())
  }

  pairs <- expand.grid(
    lang = languages,
    tmpl = base_templates,
    stringsAsFactors = FALSE
  )

  if (nrow(pairs) == 0) {
    return(i18n_empty_validation_df())
  }

  results <- mapply(
    i18n_validate_one,
    pairs$lang,
    pairs$tmpl,
    MoreArgs = list(base_dir = base_dir),
    SIMPLIFY = FALSE
  )

  do.call(rbind, results)
}

i18n_languages <- function(language) {
  langs <- if (is.null(language)) {
    config <- load_languages_config()
    vapply(config$supported, function(l) l$code, character(1))
  } else {
    language
  }
  setdiff(langs, "en")
}

i18n_base_dir <- function() {
  dir <- system.file("translations", "en", package = "jinx")
  if (nzchar(dir)) dir else system.file("templates", package = "jinx")
}

i18n_validate_one <- function(lang, tmpl, base_dir) {
  trans_path <- system.file("translations", lang, tmpl, package = "jinx")
  if (!nzchar(trans_path)) {
    return(i18n_validation_row(tmpl, lang, "missing", "", ""))
  }

  base_keys <- extract_placeholder_keys(file.path(base_dir, tmpl))
  trans_keys <- extract_placeholder_keys(trans_path)
  missing <- setdiff(base_keys, trans_keys)
  extra <- setdiff(trans_keys, base_keys)

  status <- if (length(missing) == 0 && length(extra) == 0) "ok" else "mismatch"
  i18n_validation_row(
    tmpl,
    lang,
    status,
    toString(missing),
    toString(extra)
  )
}

i18n_validation_row <- function(tmpl, lang, status, missing, extra) {
  data.frame(
    template = tmpl,
    language = lang,
    status = status,
    missing_keys = missing,
    extra_keys = extra,
    stringsAsFactors = FALSE
  )
}

i18n_empty_validation_df <- function() {
  data.frame(
    template = character(0),
    language = character(0),
    status = character(0),
    missing_keys = character(0),
    extra_keys = character(0),
    stringsAsFactors = FALSE
  )
}

#' Check translation coverage across languages
#'
#' @return Data frame with columns: language, total_templates, translated,
#'   coverage_pct.
#' @export
i18n_coverage_check <- function() {
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
