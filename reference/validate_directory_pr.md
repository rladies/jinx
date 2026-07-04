# Post an automated directory review as a PR comment

Runs the checks that used to be manual review-checklist items on the
entry files changed in a PR (filenames, likely-duplicate slugs, contact
method vs. social entry, stray contact info in free text, and whether
social handles resolve) and posts a single consolidated report. Schema
validity is covered separately by the directory repo's JSON validation.

## Usage

``` r
validate_directory_pr(owner, repo, pr_number, verify_handles = TRUE)
```

## Arguments

- owner:

  Repository owner.

- repo:

  Repository name.

- pr_number:

  PR number.

- verify_handles:

  Whether to HTTP-check that social handles resolve. Defaults to `TRUE`;
  set `FALSE` to skip the network calls.

## Value

Invisibly `NULL`.
