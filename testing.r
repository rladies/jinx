library(httr)
library(jsonlite)
library(plumber)

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

# Function to greet new contributors
greet_contributor <- function(issue_url, contributor) {
  message <- paste0("Hello @", contributor, "! Welcome to our organization. Thank you for your contribution.")
  post_comment(issue_url, message)
}

# Function to post response time message
post_response_time_message <- function(issue_url) {
  message <- "Thank you for your contribution. Please note that we are a volunteer organization and response times may vary. We appreciate your patience."
  post_comment(issue_url, message)
}

# Webhook endpoint to handle GitHub events
handle_webhook <- function(req) {
  event <- req$headers$`X-GitHub-Event`
  payload <- fromJSON(req$postBody)
  
  if (event == "issues" && payload$action == "opened") {
    greet_contributor(payload$issue$comments_url, payload$issue$user$login)
  } else if (event == "pull_request" && payload$action == "opened") {
    post_response_time_message(payload$pull_request$comments_url)
  }
  
  return(200)
}

# Create a Plumber router
router <- plumb("path/to/your/router.R")
router$registerHooks(list(handle_webhook))

# Start the Plumber API
router$run(port = 8000)
