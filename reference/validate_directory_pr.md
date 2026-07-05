# Post an automated directory review as a PR checklist comment

Runs the checks that used to be manual review-checklist items on the
entry files changed in a PR (filenames, likely-duplicate slugs, contact
method vs. social entry, stray contact info in free text) and posts a
single consolidated checklist. Each entry lists clickable profile links
so reviewers can confirm the social accounts resolve, rather than an
unreliable automated check (the platforms block bot requests). Schema
validity is covered separately by the directory repo's JSON validation.

## Usage

``` r
validate_directory_pr(owner, repo, pr_number)
```

## Arguments

- owner:

  Repository owner.

- repo:

  Repository name.

- pr_number:

  PR number.

## Value

Invisibly `NULL`.
