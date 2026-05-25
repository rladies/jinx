# Test whether a value should be treated as "missing" by `%or%`

Catches NULL, zero-length vectors and lists (including the
empty-JSON-object case [`list()`](https://rdrr.io/r/base/list.html) from
[`jsonlite::fromJSON`](https://jeroen.r-universe.dev/jsonlite/reference/fromJSON.html)),
and length-1 atomic values that are `NA` or `""`.

## Usage

``` r
is_blank(x)
```
