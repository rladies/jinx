# Publish GHA dashboard as a GitHub issue

Creates a summary issue with workflow status badges.

## Usage

``` r
gha_publish_dashboard(
  dashboard_data,
  org = "rladies",
  target_repo = "global-team"
)
```

## Arguments

- dashboard_data:

  Data from
  [`gha_generate_dashboard()`](https://rladies.github.io/jinx/reference/gha_generate_dashboard.md).

- org:

  GitHub organization.

- target_repo:

  Repository to publish to.

## Value

Issue URL (invisibly).
