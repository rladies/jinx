# Post the duplicate check onto an onboarding issue

Runs
[`chapter_duplicate_check()`](https://rladies.github.io/jinx/reference/chapter_duplicate_check.md)
and comments the rendered report on the issue. Failures are reported but
never abort onboarding: the check is an aid to the team, not a gate.

## Usage

``` r
chapter_duplicate_comment(
  issue_number,
  city,
  country,
  region = NULL,
  org = "rladies",
  onboarding_repo = "new-chapters-onboarding"
)
```

## Arguments

- issue_number:

  Onboarding issue number.

- city:

  Requested chapter city.

- country:

  Requested chapter country.

- region:

  State/region/province, or `NULL`.

- org:

  GitHub organization. Defaults to `"rladies"`.

- onboarding_repo:

  Repository holding onboarding issues.

## Value

The rendered report (invisibly), or `NULL` on failure.
