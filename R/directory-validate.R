#' Validate directory entry JSON files against schema
#'
#' @param path Path to a directory containing JSON entry files, or a single
#'   JSON file path.
#' @param schema Path to JSON schema file. Uses the bundled schema by default.
#' @return A data frame with columns `file`, `valid`, and `errors`.
#' @export
validate_directory_entries <- function(
  path,
  schema = system.file("schemas", "directory-entry.json", package = "jinx")
) {
  if (!nzchar(schema)) {
    cli::cli_abort("Directory entry schema not found in jinx package")
  }

  files <- if (dir.exists(path)) {
    list.files(path, pattern = "\\.json$", full.names = TRUE)
  } else {
    path
  }

  results <- lapply(files, function(f) {
    tryCatch(
      {
        content <- jsonlite::read_json(f, simplifyVector = FALSE)
        valid <- jsonvalidate::json_validate(
          jsonlite::toJSON(content, auto_unbox = TRUE),
          schema,
          verbose = TRUE
        )
        errors <- if (isTRUE(valid)) {
          character(0)
        } else {
          attr(valid, "errors")$message
        }
        data.frame(
          file = basename(f),
          valid = isTRUE(valid),
          errors = paste(errors, collapse = "; "),
          stringsAsFactors = FALSE
        )
      },
      error = function(e) {
        data.frame(
          file = basename(f),
          valid = FALSE,
          errors = e$message,
          stringsAsFactors = FALSE
        )
      }
    )
  })

  do.call(rbind, results)
}
