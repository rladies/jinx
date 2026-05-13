# Publish a report as a GitHub issue

Publish a report as a GitHub issue

## Usage

``` r
report_publish(report, target_repo = "global-team", org = "rladies")
```

## Arguments

- report:

  Report data from
  [`report_generate()`](https://rladies.github.io/jinx/reference/report_generate.md).

- target_repo:

  Repository to publish to. Defaults to `"global-team"`.

- org:

  Organization. Defaults to `"rladies"`.

## Value

Issue URL (invisibly).
