# Validate a directory entry filename

Checks that filenames follow conventions: lowercase, no hashes,
ASCII-only, `.json` extension.

## Usage

``` r
directory_validate_filename(filename)
```

## Arguments

- filename:

  Filename (not full path) to validate.

## Value

A named list with `valid` (logical) and `issues` (character vector of
problems found).
