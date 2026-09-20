# Parse a model completion into a structured challenge

Tolerates prose or code fences around the JSON. Returns `NULL` for any
output missing a required field, carrying an unknown difficulty, or
without at least one machine-checkable test, so callers can regenerate.

## Usage

``` r
r_challenge_parse(text)
```

## Arguments

- text:

  Raw model completion from
  [`r_challenge_generate()`](https://rladies.github.io/jinx/reference/r_challenge_generate.md).

## Value

A list with elements `title`, `difficulty`, `statement`, `solution`, and
`tests` (character vector), or `NULL` if invalid.
