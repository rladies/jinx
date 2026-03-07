# Publish GHA dashboard as a GitHub issue

Creates a summary issue with workflow status badges.

## Usage

``` r
publish_gha_dashboard(
  dashboard_data,
  org = "rladies",
  target_repo = "global-team"
)
```

## Arguments

- dashboard_data:

  Data from
  [`generate_gha_dashboard()`](https://rladies.github.io/jinx/reference/generate_gha_dashboard.md).

- org:

  GitHub organization.

- target_repo:

  Repository to publish to.

## Value

Issue URL (invisibly).
