#' Validate blog entry JSON files against schema
#'
#' @param path Path to a directory containing blog JSON files, or a single
#'   JSON file path.
#' @param schema Path to JSON schema file. Uses the bundled schema by default.
#' @return A data frame with columns `file`, `valid`, and `errors`.
#' @export
validate_blog_entry <- function(
  path,
  schema = system.file("schemas", "blog-entry.json", package = "jinx")
) {
  if (!nzchar(schema)) {
    cli::cli_abort("Blog entry schema not found in jinx package")
  }

  files <- if (dir.exists(path)) {
    list.files(path, pattern = "\\.json$", full.names = TRUE)
  } else {
    path
  }

  results <- lapply(files, function(f) {
    tryCatch(
      {
        content <- readLines(f, warn = FALSE)
        valid <- jsonvalidate::json_validate(
          paste(content, collapse = "\n"),
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
