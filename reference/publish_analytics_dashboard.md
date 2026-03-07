# Publish analytics dashboard as a GitHub issue

Publish analytics dashboard as a GitHub issue

## Usage

``` r
publish_analytics_dashboard(
  dashboard_data,
  org = "rladies",
  target_repo = "global-team"
)
```

## Arguments

- dashboard_data:

  Data from
  [`generate_analytics_dashboard()`](https://rladies.github.io/jinx/reference/generate_analytics_dashboard.md).

- org:

  GitHub organization.

- target_repo:

  Repository to publish to.

## Value

Issue URL (invisibly).
