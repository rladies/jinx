# Read the machine-readable block off an onboarding issue

Read the machine-readable block off an onboarding issue

## Usage

``` r
chapter_meta_fetch(
  issue_number,
  org = "rladies",
  onboarding_repo = "new-chapters-onboarding"
)
```

## Arguments

- issue_number:

  Onboarding issue number.

- org:

  GitHub organization. Defaults to `"rladies"`.

- onboarding_repo:

  Repository holding onboarding issues.

## Value

A named list of chapter details, or `NULL` when the issue carries no
block.
