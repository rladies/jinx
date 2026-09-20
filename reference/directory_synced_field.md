# Checkbox field on the `submissions` table flagging a processed submission.

Set to `TRUE` by
[`directory_mark_synced()`](https://rladies.github.io/jinx/reference/directory_mark_synced.md)
once a submission's entry is live in the directory, so subsequent syncs
skip it. Must exist on the table.

## Usage

``` r
directory_synced_field()
```
