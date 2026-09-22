# Report the state of a chapter onboarding

Accepts either an issue number or a city name, and renders the checklist
summary that `/jinx chapter-status` replies with.

## Usage

``` r
chapter_status_report(
  ref,
  org = "rladies",
  onboarding_repo = "new-chapters-onboarding"
)
```

## Arguments

- ref:

  Issue number, or a city name to look one up by.

- org:

  GitHub organization. Defaults to `"rladies"`.

- onboarding_repo:

  Repository holding onboarding issues.

## Value

Markdown body as a single string.
