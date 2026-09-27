# Render chapter validation issues as markdown

Render chapter validation issues as markdown

## Usage

``` r
chapter_validate_report(issues, n_files = NA_integer_)
```

## Arguments

- issues:

  Data frame returned by
  [`chapter_validate_files()`](https://rladies.github.io/jinx/reference/chapter_validate_files.md).

- n_files:

  Number of files that were checked.

## Value

A markdown string suitable for a pull request comment.
