
# Function to run your R function and post the result as a comment
run_r_function <- function(issue_url) {
  # Replace this with your actual R function that returns a data frame
  result <- data.frame(
    Name = c("John", "Alice"),
    Email = c("john@example.com", "alice@example.com")
  )

  # Post the result as a comment on the PR
  post_comment(issue_url, paste("R Function Result:\n", head(result)))
}

# Webhook endpoint to handle GitHub events
handle_webhook <- function(req) {
  event <- req$headers$`X-GitHub-Event`
  payload <- fromJSON(req$postBody)

  if (event == "issue_comment" &&
      contains_command(payload$comment$body, "jinx check chapter emails")) {
    run_r_function(payload$issue$comments_url)
  }

  return(200)
}

