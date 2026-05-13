# Generate GitHub Actions dashboard data

Scans all non-meetup repositories in the organization, collects workflow
information, and generates a JSON report.

## Usage

``` r
gha_generate_dashboard(
  org = "rladies",
  exclude_pattern = "^meetup-",
  output_path = NULL
)
```

## Arguments

- org:

  GitHub organization. Defaults to `"rladies"`.

- exclude_pattern:

  Regex pattern to exclude repos. Defaults to `"^meetup-"`.

- output_path:

  Path to write the JSON report. If `NULL`, returns the data without
  writing.

## Value

List of workflow data (invisibly).
