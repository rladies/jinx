# Find the open onboarding issue for a chapter

Matches on the issue title, which onboarding issues open as ", chapter
setup".

## Usage

``` r
chapter_find_issue(
  city,
  org = "rladies",
  onboarding_repo = "new-chapters-onboarding"
)
```

## Arguments

- city:

  Chapter city.

- org:

  GitHub organization. Defaults to `"rladies"`.

- onboarding_repo:

  Repository holding onboarding issues.

## Value

The issue number, or `NULL` when no open issue matches.
