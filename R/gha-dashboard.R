#' Generate GitHub Actions dashboard data
#'
#' Scans all non-meetup repositories in the organization, collects
#' workflow information, and generates a JSON report.
#'
#' @param org GitHub organization. Defaults to `"rladies"`.
#' @param exclude_pattern Regex pattern to exclude repos.
#'   Defaults to `"^meetup-"`.
#' @param output_path Path to write the JSON report.
#'   If `NULL`, returns the data without writing.
#' @return List of workflow data (invisibly).
#' @export
gha_generate_dashboard <- function(
  org = "rladies",
  exclude_pattern = "^meetup-",
  output_path = NULL
) {
  cli::cli_h2("Generating GitHub Actions dashboard for {org}")

  repos <- gh::gh(
    "GET /orgs/{org}/repos",
    org = org,
    type = "all",
    .limit = Inf
  )

  repos <- Filter(function(r) !grepl(exclude_pattern, r$name), repos)
  cli::cli_alert_info("Scanning {length(repos)} repositories")

  dashboard_data <- list()

  for (r in repos) {
    workflows <- tryCatch(
      {
        wfs <- gh::gh(
          "GET /repos/{owner}/{repo}/actions/workflows",
          owner = org,
          repo = r$name,
          .limit = Inf
        )
        if (length(wfs$workflows) == 0) {
          next
        }

        wf_data <- lapply(wfs$workflows, function(w) {
          list(
            name = w$name,
            url = w$html_url,
            badge = w$badge_url,
            run = w$updated_at,
            state = w$state
          )
        })

        dashboard_data[[length(dashboard_data) + 1]] <- list(
          repository = r$name,
          workflows = wf_data
        )
      },
      error = function(e) NULL
    )
  }

  cli::cli_alert_success(
    "Found workflows in {length(dashboard_data)} repositories"
  )

  if (!is.null(output_path)) {
    dir.create(dirname(output_path), recursive = TRUE, showWarnings = FALSE)
    jsonlite::write_json(
      dashboard_data,
      output_path,
      pretty = TRUE,
      auto_unbox = TRUE
    )
    cli::cli_alert_success("Dashboard data written to {output_path}")
  }

  invisible(dashboard_data)
}

#' Publish GHA dashboard as a GitHub issue
#'
#' Creates a summary issue with workflow status badges.
#'
#' @param dashboard_data Data from [gha_generate_dashboard()].
#' @param org GitHub organization.
#' @param target_repo Repository to publish to.
#' @return Issue URL (invisibly).
#' @export
gha_publish_dashboard <- function(
  dashboard_data,
  org = "rladies",
  target_repo = "global-team"
) {
  body <- format_gha_dashboard(dashboard_data)

  issue <- gh::gh(
    "POST /repos/{owner}/{repo}/issues",
    owner = org,
    repo = target_repo,
    title = glue::glue("GitHub Actions Status Report - {Sys.Date()}"),
    body = body,
    labels = list("report", "gha-dashboard")
  )

  cli::cli_alert_success("Dashboard published: {issue$html_url}")
  invisible(issue$html_url)
}

format_gha_dashboard <- function(dashboard_data) {
  if (length(dashboard_data) == 0) {
    return("No workflow data found.")
  }

  header <- paste0(
    "## GitHub Actions Status Report\n",
    "**Generated**: ",
    Sys.Date(),
    "\n\n",
    "| Repository | Workflow | Last Run | Status |\n",
    "|------------|----------|----------|--------|\n"
  )

  rows <- character(0)
  for (repo_data in dashboard_data) {
    for (wf in repo_data$workflows) {
      run_date <- if (!is.null(wf$run)) {
        substr(wf$run, 1, 10)
      } else {
        "N/A"
      }
      badge <- if (!is.null(wf$badge)) {
        glue::glue("![{wf$name}]({wf$badge})")
      } else {
        wf$state %||% "unknown"
      }
      rows <- c(
        rows,
        glue::glue(
          "| {repo_data$repository} | [{wf$name}]({wf$url})",
          " | {run_date} | {badge} |"
        )
      )
    }
  }

  paste0(header, paste(rows, collapse = "\n"), "\n")
}
