# Publish event summary as a GitHub issue

Publish event summary as a GitHub issue

## Usage

``` r
events_publish_summary(summary, org = "rladies", target_repo = "global-team")
```

## Arguments

- summary:

  Formatted summary from
  [`events_create_summary()`](https://rladies.github.io/jinx/reference/create_event_summary.md).

- org:

  GitHub organization.

- target_repo:

  Repository to publish to.

## Value

Issue URL (invisibly).
