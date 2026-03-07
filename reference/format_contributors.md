# Generate a contributors markdown section

Creates a markdown table or image grid of contributors for inclusion in
README or other documents.

## Usage

``` r
format_contributors(contributors, format = c("table", "grid"), cols = 7)
```

## Arguments

- contributors:

  Data frame from
  [`list_contributors()`](https://rladies.github.io/jinx/reference/list_contributors.md).

- format:

  Output format: `"table"` or `"grid"`.

- cols:

  Number of columns for grid format. Defaults to 7.

## Value

Character string with markdown content.
