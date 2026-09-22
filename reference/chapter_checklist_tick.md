# Tick a checklist item on an onboarding issue

Tick a checklist item on an onboarding issue

## Usage

``` r
chapter_checklist_tick(
  issue_number,
  pattern,
  org = "rladies",
  onboarding_repo = "new-chapters-onboarding"
)
```

## Arguments

- issue_number:

  Onboarding issue number.

- pattern:

  Text identifying the item to tick.

- org:

  GitHub organization. Defaults to `"rladies"`.

- onboarding_repo:

  Repository holding onboarding issues.

## Value

`TRUE` when an item was ticked, `FALSE` otherwise.
