# Publish website analytics as a GitHub issue

Publish website analytics as a GitHub issue

## Usage

``` r
publish_website_report(
  report_data,
  org = "rladies",
  target_repo = "global-team",
  slack_channel = NULL
)
```

## Arguments

- report_data:

  Data from
  [`generate_website_report()`](https://rladies.github.io/jinx/reference/generate_website_report.md).

- org:

  GitHub organization.

- target_repo:

  Repository to publish to.

- slack_channel:

  Optional Slack channel to post a summary to.

## Value

Issue URL (invisibly).
