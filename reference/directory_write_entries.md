# Write changed directory entries to the directory repo (in memory).

For each submission, fetches the existing entry (if any), merges the
submission onto it (clearing requested fields first), and records a file
change only when the resulting content differs. Contact emails and
profile photos are handled alongside the entry JSON. Returns a flat list
of pending file changes for
[`directory_create_pr()`](https://rladies.github.io/jinx/reference/directory_create_pr.md)
to commit.

## Usage

``` r
directory_write_entries(entries, org, repo, ref = "main")
```
