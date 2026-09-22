# Read the checklist state of a chapter onboarding issue

Parses the task list in an onboarding issue body into one row per
checklist item, carrying the section it sits under and the team that
section says is responsible for it. Nested items inherit their parent's
owner.

## Usage

``` r
chapter_onboard_state(
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

A data frame with columns `section`, `owner`, `item`, and `done`.
