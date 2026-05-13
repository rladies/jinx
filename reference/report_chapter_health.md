# Generate a chapter health report

Analyzes chapter activity data and publishes a summary report.

## Usage

``` r
chapter_report_health(months = 6, org = "rladies", target_repo = "global-team")
```

## Arguments

- months:

  Inactivity threshold in months. Defaults to 6.

- org:

  GitHub organization. Defaults to `"rladies"`.

- target_repo:

  Repository to publish report to. Defaults to `"global-team"`.

## Value

Issue URL (invisibly).
