library(httr)
library(jsonlite)

# GitHub API base URL
base_url <- "https://api.github.com"

# GitHub OAuth app credentials
client_id <- "YOUR_CLIENT_ID"
client_secret <- "YOUR_CLIENT_SECRET"

# Function to authenticate with GitHub
authenticate <- function() {
  app <- oauth_app("github", key = client_id, secret = client_secret)
  token <- oauth2.0_token(oauth_endpoints("github"), app)
  config <- config(token = token)
  config
}

# Function to post a comment on a PR or issue
post_comment <- function(url, message) {
  config <- authenticate()
  body <- list(body = message)
  response <- POST(url, config = config, body = body)
  if (response$status_code == 201) {
    print("Comment posted successfully!")
  } else {
    print("Failed to post comment.")
  }
}

# Function to check if a comment contains a specific command
contains_command <- function(comment_body, command) {
  grepl(command, comment_body, ignore.case = TRUE)
}
