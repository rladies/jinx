# Drop submissions already flagged as synced.

A submission carries the
[`directory_synced_field()`](https://rladies.github.io/jinx/reference/directory_synced_field.md)
checkbox once its entry is live in the directory; Airtable omits
unchecked boxes, so absence means unsynced.

## Usage

``` r
directory_drop_synced(submissions)
```
