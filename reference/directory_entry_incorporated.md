# Is a submission already fully present on `main`?

True when applying the submission would produce no change at all —
entry, photo, and contact all already reflect it (the same predicate the
sync uses to decide whether to commit). Checking only the entry file
would flag a submission whose sole pending change is the email or photo
as done before that change lands, dropping it.

## Usage

``` r
directory_entry_incorporated(entry, org, repo, ref = "main")
```
