# Generate a website analytics report

Collects website analytics and formats as markdown.

## Usage

``` r
website_generate_report(
  from = NULL,
  to = NULL,
  period = NULL,
  output_path = NULL
)
```

## Arguments

- from, to:

  Date window (a `Date` or `"YYYY-MM-DD"` string). When both are `NULL`,
  defaults to the last 30 days.

- period:

  Deprecated Plausible period string, accepted for backward
  compatibility with the command registry and ignored.

- output_path:

  Optional path to write JSON data.

## Value

Named list with `analytics` and `markdown` (invisibly).
