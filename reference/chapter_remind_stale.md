# Nudge the team holding up a stale chapter onboarding

Finds open onboarding issues with no activity for `days` days and
comments on each, naming the team that owns the first unchecked step
rather than pinging everyone. Onboardings stall on the email and Meetup
Pro teams more than anywhere else, so the ping is targeted.

## Usage

``` r
chapter_remind_stale(
  org = "rladies",
  onboarding_repo = "new-chapters-onboarding",
  days = 14,
  labels = c("new chapter", "chapter update")
)
```

## Arguments

- org:

  GitHub organization. Defaults to `"rladies"`.

- onboarding_repo:

  Repository holding onboarding issues.

- days:

  Days without activity before nudging. Defaults to 14.

- labels:

  Issue labels to consider.

## Value

Invisibly, a list of the issues nudged.
