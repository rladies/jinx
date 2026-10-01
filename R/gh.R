#' Welcome a contributor on a new PR or issue
#'
#' Checks if the PR/issue author has previous contributions to the repo.
#' If this is their first, posts a warm welcome message. If not, posts a
#' shorter thank-you. No-op for bots and global team members.
#'
#' @param owner Repository owner.
#' @param repo Repository name.
#' @param number Issue or PR number.
#' @param author GitHub login of the author.
#' @param is_pr Whether this is a PR (TRUE) or issue (FALSE).
#' @param org Organization name.
#' @param extra_message Optional extra markdown to append after the
#'   standard welcome message (e.g. a project-specific reminder).
#'   Ignored when blank or `NULL`. The jinx signature is preserved as
#'   the final paragraph.
#' @return Comment URL or `NULL` if author is a team member (invisibly).
#' @export
gh_welcome_contributor <- function(
  owner,
  repo,
  number,
  author,
  is_pr = TRUE,
  org = "rladies",
  extra_message = NULL
) {
  if (is_bot(author)) {
    return(invisible(NULL))
  }

  if (is_team_member(author, org)) {
    return(invisible(NULL))
  }

  first_time <- is_first_time_contributor(owner, repo, author, is_pr)

  message <- if (first_time) {
    gh_welcome_message_first_time(author, repo, is_pr)
  } else {
    gh_welcome_message_returning(author, is_pr)
  }

  message <- gh_welcome_message_with_extra(message, extra_message)

  comment <- gh::gh(
    "POST /repos/{owner}/{repo}/issues/{issue_number}/comments",
    owner = owner,
    repo = repo,
    issue_number = number,
    body = message
  )

  cli::cli_alert_success("Welcomed {author} on {owner}/{repo}#{number}")
  invisible(comment$html_url)
}

#' Thank everyone who contributed to a merged PR
#'
#' Posts a thank-you message tailored to whether this is the author's
#' first merged PR, and credits everyone else who helped: co-authors
#' (commit authors and `Co-authored-by:` trailers), reviewers, and
#' people who commented on the PR.
#'
#' @param owner Repository owner.
#' @param repo Repository name.
#' @param pr_number PR number.
#' @param author GitHub login of the PR author.
#' @param org Organization name.
#' @return Comment URL (invisibly).
#' @export
gh_thank_contributor <- function(
  owner,
  repo,
  pr_number,
  author,
  org = "rladies"
) {
  if (is_bot(author)) {
    return(invisible(NULL))
  }

  first_time <- is_first_time_contributor(owner, repo, author, is_pr = TRUE)
  helpers <- gh_pr_helpers(owner, repo, pr_number, author)
  message <- gh_thank_message(author, repo, first_time, helpers)

  comment <- gh::gh(
    "POST /repos/{owner}/{repo}/issues/{issue_number}/comments",
    owner = owner,
    repo = repo,
    issue_number = pr_number,
    body = message
  )

  invisible(comment$html_url)
}

#' Greet a new PR author
#'
#' Thin wrapper around [gh_welcome_contributor()] that fixes `is_pr =
#' TRUE` for use in PR-only workflows. Reusable across any repo.
#'
#' @param owner Repository owner.
#' @param repo Repository name.
#' @param number PR number.
#' @param author GitHub login of the author.
#' @param org Organization name.
#' @param extra_message Optional extra markdown to append after the
#'   standard welcome message.
#' @return Comment URL or `NULL` if author is a team member (invisibly).
#' @export
gh_greet_contributor <- function(
  owner,
  repo,
  number,
  author,
  org = "rladies",
  extra_message = NULL
) {
  gh_welcome_contributor(
    owner,
    repo,
    number,
    author,
    is_pr = TRUE,
    org = org,
    extra_message = extra_message
  )
}

#' Post a content review checklist on a PR
#'
#' Posts a review checklist comment tailored for content PRs (blog
#' posts, news posts, or any markdown-driven content). Generic across
#' content kinds — the only difference between blog and news today is
#' the path filter the caller workflow applies.
#'
#' @param owner Repository owner.
#' @param repo Repository name.
#' @param pr_number PR number.
#' @return Comment URL (invisibly).
#' @export
gh_post_checklist <- function(owner, repo, pr_number) {
  checklist <- paste(
    "Thank you for submitting a post to RLadies+!",
    "",
    "## Content Checklist",
    "- [ ] Ensure the PR is kept as a draft until you are ready for review.",
    "- [ ] Ensure the title is appropriate for publication.",
    "- [ ] Ensure all links are working and point to correct destinations.",
    "- [ ] Ensure internal cross-references (if any) are correct.",
    paste0(
      "- [ ] If the main document is a `qmd` or `rmd`,",
      " make sure the knitted `md` is committed."
    ),
    "- [ ] Ensure no sensitive or confidential information is included.",
    "- [ ] Check grammar and spelling.",
    "- [ ] Ensure all images have alt text `![alt goes here](image.png)`.",
    "",
    "### Review ready",
    paste0(
      "- [ ] Remove draft mode for the PR,",
      " reviewers will be automatically assigned."
    ),
    "",
    "### Reviewers",
    "- [ ] Verify the title is appropriate for publication.",
    "- [ ] Verify all links are working.",
    "- [ ] Verify all images have alt text.",
    paste0(
      "- [ ] If the main document is a `qmd` or `rmd`,",
      " verify the `md` is up to date."
    ),
    "",
    "### Publication",
    "- [ ] Set a date for publication.",
    paste0(
      '- [ ] Change label to "pending" - publication',
      " will happen automatically on that day."
    ),
    "",
    "_Generated by jinx_",
    sep = "\n"
  )

  comment <- gh::gh(
    "POST /repos/{owner}/{repo}/issues/{issue_number}/comments",
    owner = owner,
    repo = repo,
    issue_number = pr_number,
    body = checklist
  )

  invisible(comment$html_url)
}

#' Create or reset a branch to match a base ref
#'
#' Reads the base branch tip and either creates `branch` there or
#' force-updates it. Used by helpers that need to (re-)open a clean
#' working branch before pushing files.
#'
#' @param org Repository owner.
#' @param repo Repository name.
#' @param branch Branch to create or update.
#' @param base Base branch whose tip is used as the new SHA.
#'   Defaults to `"main"`.
#' @param force Whether to force-update if the branch already exists.
#'   Defaults to `TRUE`.
#' @return The SHA the branch now points to (invisibly).
#' @export
gh_branch_upsert <- function(org, repo, branch, base = "main", force = TRUE) {
  base_ref <- gh::gh(
    "GET /repos/{owner}/{repo}/git/ref/heads/{branch}",
    owner = org,
    repo = repo,
    branch = base
  )
  sha <- base_ref$object$sha

  result <- tryCatch(
    {
      gh::gh(
        "POST /repos/{owner}/{repo}/git/refs",
        owner = org,
        repo = repo,
        ref = glue::glue("refs/heads/{branch}"),
        sha = sha
      )
      list(created = TRUE, sha = sha)
    },
    error = function(e) {
      if (!force) {
        cli::cli_alert_info("Branch {branch} may already exist")
        head <- tryCatch(
          gh::gh(
            "GET /repos/{owner}/{repo}/git/ref/heads/{branch}",
            owner = org,
            repo = repo,
            branch = branch
          ),
          error = function(e2) NULL
        )
        return(list(created = FALSE, sha = head$object$sha))
      }
      gh::gh(
        "PATCH /repos/{owner}/{repo}/git/refs/heads/{branch}",
        owner = org,
        repo = repo,
        branch = branch,
        sha = sha,
        force = TRUE
      )
      list(created = TRUE, sha = sha)
    }
  )

  invisible(result$sha)
}

#' Open a PR, or return the existing open PR for a branch
#'
#' If a PR is already open from `branch` into `base`, returns its URL;
#' otherwise opens a new PR with the given title and body.
#'
#' @param org Repository owner.
#' @param repo Repository name.
#' @param branch Head branch.
#' @param base Base branch. Defaults to `"main"`.
#' @param title PR title.
#' @param body PR body.
#' @param team_reviewers Character vector of org team slugs to request
#'   review from, or `NULL` for none.
#' @return PR URL.
#' @export
gh_open_or_update_pr <- function(
  org,
  repo,
  branch,
  base = "main",
  title,
  body,
  team_reviewers = NULL
) {
  existing <- tryCatch(
    gh::gh(
      "GET /repos/{owner}/{repo}/pulls",
      owner = org,
      repo = repo,
      head = glue::glue("{org}:{branch}"),
      state = "open"
    ),
    error = function(e) list()
  )

  if (length(existing) > 0) {
    return(existing[[1]]$html_url)
  }

  pr <- gh::gh(
    "POST /repos/{owner}/{repo}/pulls",
    owner = org,
    repo = repo,
    title = title,
    head = branch,
    base = base,
    body = body
  )
  gh_request_team_review(org, repo, pr$number, team_reviewers)
  pr$html_url
}

#' Ask one or more org teams to review a pull request
#'
#' A failed review request is reported but never fails the PR: the PR
#' itself is the deliverable, and a missing reviewer can be added by
#' hand.
#'
#' @param org GitHub organization.
#' @param repo Repository name.
#' @param number Pull request number.
#' @param team_reviewers Character vector of team slugs, or `NULL`.
#' @return Invisibly, `TRUE` when a request was made.
#' @keywords internal
#' @noRd
gh_request_team_review <- function(org, repo, number, team_reviewers) {
  if (is.null(team_reviewers) || length(team_reviewers) == 0) {
    return(invisible(FALSE))
  }
  tryCatch(
    {
      gh::gh(
        "POST /repos/{owner}/{repo}/pulls/{pull_number}/requested_reviewers",
        owner = org,
        repo = repo,
        pull_number = number,
        team_reviewers = as.list(team_reviewers)
      )
      invisible(TRUE)
    },
    error = function(e) {
      cli::cli_alert_warning(
        "Could not request review from {toString(team_reviewers)}: {e$message}"
      )
      invisible(FALSE)
    }
  )
}

is_first_time_contributor <- function(owner, repo, author, is_pr = TRUE) {
  kind <- if (is_pr) "pr" else "issue"
  query <- glue::glue("repo:{owner}/{repo} is:{kind} author:{author}")
  result <- tryCatch(
    gh::gh(
      "GET /search/issues",
      q = query,
      per_page = 2
    ),
    error = function(e) NULL
  )
  if (is.null(result) || is.null(result$total_count)) {
    return(FALSE)
  }
  result$total_count <= 1
}

is_team_member <- function(author, org, team = "global") {
  result <- tryCatch(
    gh::gh(
      "GET /orgs/{org}/teams/{team}/memberships/{username}",
      org = org,
      team = team,
      username = author
    ),
    http_error_404 = function(e) "not_member",
    error = function(e) "unknown"
  )
  if (identical(result, "not_member")) {
    return(FALSE)
  }
  if (identical(result, "unknown")) {
    cli::cli_alert_warning(
      "Team membership check failed for @{author}; treating as member"
    )
    return(TRUE)
  }
  TRUE
}

is_bot <- function(login) {
  grepl("\\[bot\\]$", login) || login %in% c("github-actions", "dependabot")
}

gh_welcome_message_first_time <- function(author, repo, is_pr) {
  type <- if (is_pr) "pull request" else "issue"
  glue::glue(
    "Welcome to **{repo}**, @{author}! ",
    "This is your first {type} here - thank you for contributing!\n\n",
    "We are a volunteer organisation, so it may take us a little while ",
    "to review, but we will get back to you as soon as we can.\n\n",
    "_Generated by jinx_"
  )
}

gh_welcome_message_returning <- function(author, is_pr) {
  type <- if (is_pr) "pull request" else "issue"
  glue::glue(
    "Thanks for the {type}, @{author}! ",
    "We will get back to you as soon as we can.\n\n",
    "_Generated by jinx_"
  )
}

gh_welcome_message_with_extra <- function(message, extra) {
  if (is.null(extra) || !nzchar(trimws(extra))) {
    return(message)
  }
  paste(
    sub("\n+_Generated by jinx_\\s*$", "", message),
    trimws(extra),
    "_Generated by jinx_",
    sep = "\n\n"
  )
}

gh_pr_helpers <- function(owner, repo, pr_number, author) {
  found <- rbind(
    gh_pr_coauthors(owner, repo, pr_number),
    gh_pr_reviewers(owner, repo, pr_number),
    gh_pr_commenters(owner, repo, pr_number)
  )
  keep <- found$login != author &
    vapply(found$login, is_valid_login, logical(1), USE.NAMES = FALSE) &
    !vapply(found$login, is_bot, logical(1), USE.NAMES = FALSE)
  found <- found[keep, , drop = FALSE]
  found <- found[!duplicated(found$login), , drop = FALSE]
  row.names(found) <- NULL
  found
}

gh_pr_coauthors <- function(owner, repo, pr_number) {
  commits <- gh_pr_fetch(
    "GET /repos/{owner}/{repo}/pulls/{pull_number}/commits",
    owner = owner,
    repo = repo,
    pull_number = pr_number
  )
  logins <- unlist(lapply(commits, function(commit) {
    c(
      commit$author$login %||% character(0),
      gh_coauthor_logins(commit$commit$message %||% "")
    )
  }))
  gh_role_frame(logins, "co-author")
}

gh_pr_reviewers <- function(owner, repo, pr_number) {
  reviews <- gh_pr_fetch(
    "GET /repos/{owner}/{repo}/pulls/{pull_number}/reviews",
    owner = owner,
    repo = repo,
    pull_number = pr_number
  )
  submitted <- Filter(
    function(review) !identical(review$state, "PENDING"),
    reviews
  )
  logins <- vapply(
    submitted,
    function(review) review$user$login %||% "",
    character(1)
  )
  gh_role_frame(logins, "reviewer")
}

gh_pr_commenters <- function(owner, repo, pr_number) {
  comments <- c(
    gh_pr_fetch(
      "GET /repos/{owner}/{repo}/issues/{issue_number}/comments",
      owner = owner,
      repo = repo,
      issue_number = pr_number
    ),
    gh_pr_fetch(
      "GET /repos/{owner}/{repo}/pulls/{pull_number}/comments",
      owner = owner,
      repo = repo,
      pull_number = pr_number
    )
  )
  logins <- vapply(
    comments,
    function(comment) comment$user$login %||% "",
    character(1)
  )
  gh_role_frame(logins, "commenter")
}

gh_pr_fetch <- function(endpoint, ...) {
  result <- tryCatch(
    gh::gh(endpoint, ..., .limit = Inf),
    error = function(e) {
      cli::cli_alert_warning("Could not fetch {endpoint}: {e$message}")
      list()
    }
  )
  if (!is.null(names(result))) {
    return(list(result))
  }
  result
}

gh_role_frame <- function(logins, role) {
  logins <- unique(logins[!is.na(logins)])
  data.frame(
    login = as.character(logins),
    role = rep(role, length(logins)),
    stringsAsFactors = FALSE
  )
}

gh_coauthor_logins <- function(message) {
  lines <- unlist(strsplit(message, "\n", fixed = TRUE))
  trailers <- grep(
    "^\\s*co-authored-by:.*<[^>]+>",
    lines,
    ignore.case = TRUE,
    value = TRUE
  )
  emails <- sub(".*<([^>]+)>.*", "\\1", trailers)
  noreply <- grep("@users\\.noreply\\.github\\.com$", emails, value = TRUE)
  logins <- sub("@users\\.noreply\\.github\\.com$", "", noreply)
  logins <- sub("^[0-9]+\\+", "", logins)
  logins[vapply(logins, is_valid_login, logical(1), USE.NAMES = FALSE)]
}

# A trailer is free text the PR author writes, so what comes out of one is
# only a login if it looks like a login: anything else would be pasted into
# a bot comment as markdown, and "@org/team" there mass-mentions a team.
is_valid_login <- function(login) {
  grepl(
    "^[A-Za-z0-9](?:[A-Za-z0-9]|-(?=[A-Za-z0-9])){0,38}$",
    login,
    perl = TRUE
  )
}

gh_thank_message <- function(author, repo, first_time, helpers) {
  opening <- if (first_time) {
    glue::glue(
      "Congratulations on your first contribution to **{repo}**, @{author}! ",
      "Thank you for helping make RLadies+ better."
    )
  } else {
    glue::glue("Thank you for your contribution, @{author}!")
  }
  paste(
    c(opening, gh_thank_helpers_line(helpers), "_Generated by jinx_"),
    collapse = "\n\n"
  )
}

gh_thank_helpers_line <- function(helpers) {
  if (nrow(helpers) == 0) {
    return(character(0))
  }
  verbs <- c(
    "co-author" = "co-authoring",
    "reviewer" = "reviewing",
    "commenter" = "joining the discussion"
  )
  clauses <- vapply(
    names(verbs),
    function(role) {
      logins <- helpers$login[helpers$role == role]
      if (length(logins) == 0) {
        return("")
      }
      glue::glue("{gh_mention_list(logins)} for {verbs[[role]]}")
    },
    character(1)
  )
  clauses <- clauses[nzchar(clauses)]
  glue::glue("Thanks also to {gh_and_list(clauses)}.")
}

gh_mention_list <- function(logins) {
  gh_and_list(paste0("@", logins))
}

gh_and_list <- function(x) {
  if (length(x) < 2) {
    return(paste(x, collapse = ""))
  }
  paste(
    paste(x[-length(x)], collapse = ", "),
    x[length(x)],
    sep = " and "
  )
}
