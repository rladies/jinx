# Verify that social media handles exist

Performs HTTP HEAD requests to check if profiles resolve.

## Usage

``` r
verify_social_handles(entry)
```

## Arguments

- entry:

  Named list representing a directory entry, with a `social_media`
  sub-list containing handles/URLs.

## Value

A data frame with columns `platform`, `handle`, `status`, and `valid`.
