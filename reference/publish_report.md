# Publish a report as a GitHub issue

Publish a report as a GitHub issue

## Usage

``` r
publish_report(report, target_repo = "global-team", org = "rladies")
```

## Arguments

- report:

  Report data from
  [`generate_report()`](https://rladies.github.io/jinx/reference/generate_report.md).

- target_repo:

  Repository to publish to. Defaults to `"global-team"`.

- org:

  Organization. Defaults to `"rladies"`.

## Value

Issue URL (invisibly).
