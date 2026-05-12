#' List open CFPs tracked as GitHub issues
#'
#' @param org GitHub organization.
#' @param repo Repository where CFP issues are tracked.
#' @return Data frame with columns: conference, deadline, url, number, status.
#' @export
list_open_cfps <- function(org = "rladies", repo = "global-team") {
  issues <- gh::gh(
    "GET /repos/{owner}/{repo}/issues",
    owner = org,
    repo = repo,
    labels = "cfp",
    state = "open",
    .limit = Inf
  )

  if (length(issues) == 0) {
    return(data.frame(
      conference = character(0),
      deadline = character(0),
      url = character(0),
      number = integer(0),
      status = character(0),
      stringsAsFactors = FALSE
    ))
  }

  rows <- lapply(issues, function(issue) {
    meta <- parse_cfp_body(issue$body %||% "")
    data.frame(
      conference = meta$conference %||% issue$title,
      deadline = meta$deadline %||% NA_character_,
      url = meta$url %||% NA_character_,
      number = issue$number,
      status = "open",
      stringsAsFactors = FALSE
    )
  })

  do.call(rbind, rows)
}

#' Create a CFP tracking issue
#'
#' @param conference Conference name.
#' @param deadline Submission deadline (YYYY-MM-DD).
#' @param url CFP URL.
#' @param topics Character vector of topic tags.
#' @param org GitHub organization.
#' @param repo Repository to create the issue in.
#' @return Issue URL (invisibly).
#' @export
create_cfp_issue <- function(
  conference,
  deadline,
  url,
  topics = character(0),
  org = "rladies",
  repo = "global-team"
) {
  template_path <- system.file(
    "templates",
    "cfp-reminder.md",
    package = "jinx"
  )

  days_left <- as.integer(as.Date(deadline) - Sys.Date())

  body <- if (nzchar(template_path)) {
    render_template(
      template_path,
      list(
        CONFERENCE = conference,
        DEADLINE = deadline,
        DAYS = as.character(days_left),
        URL = url
      )
    )
  } else {
    cli::format_inline(
      "**{conference}**\n\nDeadline: {deadline} ({days_left} days)\nURL: {url}"
    )
  }

  meta_block <- cli::format_inline(paste0(
    "\n\n<!-- cfp-meta\n",
    "conference: {conference}\n",
    "deadline: {deadline}\n",
    "url: {url}\n-->"
  ))

  labels <- list("cfp")
  if (days_left <= 7) {
    labels <- c(labels, "deadline-approaching")
  }

  issue <- gh::gh(
    "POST /repos/{owner}/{repo}/issues",
    owner = org,
    repo = repo,
    title = cli::format_inline("CFP: {conference} (deadline {deadline})"),
    body = paste0(body, meta_block),
    labels = labels
  )

  cli::cli_alert_success("CFP issue created: {issue$html_url}")
  invisible(issue$html_url)
}

#' Check CFP deadlines and post reminders
#'
#' @param org GitHub organization.
#' @param repo Repository where CFP issues are tracked.
#' @param warn_days Number of days before deadline to warn.
#' @return Data frame of approaching CFPs (invisibly).
#' @export
check_cfp_deadlines <- function(
  org = "rladies",
  repo = "global-team",
  warn_days = 7
) {
  cfps <- list_open_cfps(org = org, repo = repo)

  if (nrow(cfps) == 0) {
    cli::cli_alert_info("No open CFPs")
    return(invisible(cfps))
  }

  cfps$days_left <- as.integer(as.Date(cfps$deadline) - Sys.Date())
  approaching <- cfps[
    !is.na(cfps$days_left) & cfps$days_left <= warn_days & cfps$days_left >= 0,
  ]

  if (nrow(approaching) == 0) {
    cli::cli_alert_info("No CFPs approaching deadline")
    return(invisible(approaching))
  }

  for (i in seq_len(nrow(approaching))) {
    reminder <- cli::format_inline(paste0(
      "Reminder: The CFP for **{approaching$conference[i]}** ",
      "closes in **{approaching$days_left[i]} days** ",
      "({approaching$deadline[i]}).\n\n",
      "{approaching$url[i]}"
    ))

    gh::gh(
      "POST /repos/{owner}/{repo}/issues/{issue_number}/comments",
      owner = org,
      repo = repo,
      issue_number = approaching$number[i],
      body = reminder
    )

    gh::gh(
      "POST /repos/{owner}/{repo}/issues/{issue_number}/labels",
      owner = org,
      repo = repo,
      issue_number = approaching$number[i],
      .send_body = list("deadline-approaching")
    )

    cli::cli_alert_success(paste0(
      "Reminded about {approaching$conference[i]}",
      " ({approaching$days_left[i]} days left)"
    ))
  }

  invisible(approaching)
}

parse_cfp_body <- function(body) {
  pattern <- "<!--\\s*cfp-meta\\n((?:.|\\n)*?)-->"
  match <- regmatches(body, regexec(pattern, body, perl = TRUE))[[1]]
  if (length(match) < 2) {
    return(list())
  }
  meta_text <- match[2]
  lines <- strsplit(trimws(meta_text), "\n")[[1]]
  result <- list()
  for (line in lines) {
    parts <- strsplit(line, ":\\s*", perl = TRUE)[[1]]
    if (length(parts) >= 2) {
      result[[parts[1]]] <- paste(parts[-1], collapse = ":")
    }
  }
  result
}
