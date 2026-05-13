# Generate a contributors markdown section

Creates a markdown table or image grid of contributors for inclusion in
README or other documents.

## Usage

``` r
contributor_format(contributors, format = c("table", "grid"), cols = 7)
```

## Arguments

- contributors:

  Data frame from
  [`contributor_list()`](https://rladies.github.io/jinx/reference/contributor_list.md).

- format:

  Output format: `"table"` or `"grid"`.

- cols:

  Number of columns for grid format. Defaults to 7.

## Value

Character string with markdown content.
