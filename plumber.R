# plumber.R
library(plumber)

#* @apiTitle Jinx: R-Ladies Companion

#* List all chapter emails missing
#* @param status which chapter statuses to return. Default is 'all'
#* @get /echo
missing_chapter_emails <- function(status = c("all", "prospective", "retired", "active")){
  username <- "rladies"
  repository <- "rladies.github.io"
  branch <- "main"
  status <- match.arg(status)
  require(httr2)
  require(jsonlite)

  # Make an HTTP GET request to the GitHub API
  response <- request("https://api.github.com/repos/") |>
    req_url_path_append(username) |>
    req_url_path_append(repository) |>
    req_url_path_append("contents") |>
    req_url_path_append("data") |>
    req_url_path_append("chapters") |>
    req_url_query(ref = branch) |>
    req_perform()

  # Check if the request was successful
  if (resp_status(response) != 200) {
    cli::cli_abort("Failed to retrieve repository contents with error code: {{status_code(response)}}")
  }

  # Parse the JSON response
  content_list <- resp_body_json(response)

  content_url <- sapply(content_list, function(x){
    x$download_url
  })

  content_jsons <- lapply(content_url, read_json)

  emails <- lapply(content_jsons, function(x){
    data.frame(
      status = x[[1]][["status"]]  %||% NA_character_,
      meetup = x[[1]][["urlname"]] %||% NA_character_,
      mail = x[[1]][["social_media"]][["email"]] %||% NA_character_
    )
  })
  emails <- do.call(rbind, emails)
  emails$file <- basename(content_url)
  emails <- emails[is.na(emails$mail), c("file", "status", "meetup", "mail")]
  emails <- emails[order(emails$status), ]
  if(status == "all")
    return(emails)
  emails[emails$status == status, ]
}


# Create a Plumber router
#router <- plumb("path/to/your/router.R")
#router$registerHooks(list(handle_webhook))

# Start the Plumber API
#router$run(port = 8000)
