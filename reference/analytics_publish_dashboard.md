# Publish analytics dashboard as a GitHub issue

Publish analytics dashboard as a GitHub issue

## Usage

``` r
analytics_publish_dashboard(
  dashboard_data,
  org = "rladies",
  target_repo = "global-team",
  slack_channel = NULL
)
```

## Arguments

- dashboard_data:

  Data from
  [`analytics_generate_dashboard()`](https://rladies.github.io/jinx/reference/analytics_generate_dashboard.md).

- org:

  GitHub organization.

- target_repo:

  Repository to publish to.

- slack_channel:

  Optional Slack channel to post a summary to.

## Value

Issue URL (invisibly).
