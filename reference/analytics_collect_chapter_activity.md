# Collect chapter activity data

Queries the GitHub API for repository activity metrics across all
non-meetup repos in the organization.

## Usage

``` r
analytics_collect_chapter_activity(
  org = "rladies",
  months = 12,
  exclude_pattern = "^meetup-"
)
```

## Arguments

- org:

  GitHub organization.

- months:

  Number of months of history.

- exclude_pattern:

  Regex pattern to exclude repos.

## Value

Data frame with columns: chapter, month, commits, prs, issues.
