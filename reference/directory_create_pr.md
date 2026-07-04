# Commit recorded changes as a single commit and open (or reuse) a PR.

Uses the git data API (blobs -\> tree -\> commit -\> ref) so the whole
sync lands as one commit, rather than one commit per file.

## Usage

``` r
directory_create_pr(changes, deletes, org, repo, base = "main")
```
