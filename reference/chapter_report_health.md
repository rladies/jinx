# Generate a chapter health report

Analyzes chapter activity data and returns a formatted markdown summary.

## Usage

``` r
chapter_report_health(months = 6, org = "rladies")
```

## Arguments

- months:

  Inactivity threshold in months. Defaults to 6.

- org:

  GitHub organization. Defaults to `"rladies"`.

## Value

Markdown report body (invisibly), or `NULL` if no data.
