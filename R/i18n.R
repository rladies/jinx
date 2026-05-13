#' Translate a template with language fallback
#'
#' Looks up `inst/translations/{language}/{template_name}.md` first,
#' falls back to `inst/templates/{template_name}.md` if the translation
#' is missing.
#'
#' @param template_name Template filename without path (e.g.
#'   "global-team-onboarding.md").
#' @param language Language code (e.g. "es", "pt", "fr"). Defaults to "en".
#' @param variables Named list of placeholder values for
#'   `render_template()`.
#' @return Rendered template as a single character string.
#' @export
i18n_translate_template <- function(
  template_name,
  language = "en",
  variables = list()
) {
  translated_path <- system.file(
    "translations",
    language,
    template_name,
    package = "jinx"
  )

  if (nzchar(translated_path)) {
    return(render_template(translated_path, variables))
  }

  if (language != "en") {
    cli::cli_alert_warning(
      "No {language} translation for {template_name}, falling back to English"
    )
  }

  base_path <- system.file("templates", template_name, package = "jinx")
  if (!nzchar(base_path)) {
    cli::cli_abort("Template {template_name} not found")
  }

  render_template(base_path, variables)
}

#' List supported languages
#'
#' @return Data frame with columns: code, name, native_name, direction.
#' @export
i18n_list_languages <- function() {
  config <- load_languages_config()
  langs <- config$supported %||% list()

  if (length(langs) == 0) {
    return(data.frame(
      code = character(0),
      name = character(0),
      native_name = character(0),
      direction = character(0),
      stringsAsFactors = FALSE
    ))
  }

  rows <- lapply(langs, function(l) {
    data.frame(
      code = l$code %||% NA_character_,
      name = l$name %||% NA_character_,
      native_name = l$native_name %||% NA_character_,
      direction = l$direction %||% "ltr",
      stringsAsFactors = FALSE
    )
  })

  do.call(rbind, rows)
}

#' Get a chapter's preferred language
#'
#' Looks up the chapter's language preference from its metadata.
#' Falls back to English if not set.
#'
#' @param chapter Chapter slug (e.g. "rladies-berlin").
#' @param org GitHub organization.
#' @return Language code string.
#' @export
chapter_get_language <- function(chapter, org = "rladies") {
  tryCatch(
    {
      content <- gh::gh(
        "GET /repos/{owner}/{repo}/contents/chapter.json",
        owner = org,
        repo = chapter
      )
      raw <- base64_decode(content$content)
      meta <- jsonlite::fromJSON(raw)
      meta$language %||% "en"
    },
    error = function(e) {
      "en"
    }
  )
}

load_languages_config <- function() {
  path <- system.file("config", "languages.yml", package = "jinx")
  if (!nzchar(path)) {
    cli::cli_abort("languages.yml not found in jinx package")
  }
  yaml::read_yaml(path)
}

base64_decode <- function(x) {
  rawToChar(jsonlite::base64_dec(gsub("\n", "", x, fixed = TRUE)))
}
