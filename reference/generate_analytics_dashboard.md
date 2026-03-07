# Generate analytics dashboard

Orchestrates data collection, trend computation, and formatting.

## Usage

``` r
generate_analytics_dashboard(org = "rladies", months = 12, output_path = NULL)
```

## Arguments

- org:

  GitHub organization.

- months:

  Number of months of history.

- output_path:

  Optional path to write JSON data.

## Value

Named list with `trends`, `growth`, and `markdown` (invisibly).
