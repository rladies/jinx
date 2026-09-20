# Has a slug's entry file been removed from `main`?

True only on a genuine 404 — the purge workflow has actioned the delete
request. Any other error (rate limit, network) propagates rather than
being read as "absent", so a flaky API call can never mark a delete
request done while the entry is still live.

## Usage

``` r
directory_entry_absent(slug, org, repo, ref = "main")
```
