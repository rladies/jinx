# Generate an organization activity report

Collects stats across org repos: commits, PRs, issues.

## Usage

``` r
report_generate(
  type = c("weekly", "monthly"),
  org = "rladies",
  exclude_pattern = "^meetup-"
)
```

## Arguments

- type:

  Report type: `"weekly"` or `"monthly"`.

- org:

  GitHub organization. Defaults to `"rladies"`.

- exclude_pattern:

  Regex to exclude repos. Defaults to `"^meetup-"`.

## Value

A named list with report data (invisibly).
