# Prompt the onboarding issue for the organiser Slack invite

Prompt the onboarding issue for the organiser Slack invite

## Usage

``` r
chapter_slack_prompt(
  issue_number,
  city = NULL,
  org = "rladies",
  onboarding_repo = "new-chapters-onboarding"
)
```

## Arguments

- issue_number:

  Onboarding issue number.

- city:

  Chapter city. Read from the issue when `NULL`.

- org:

  GitHub organization. Defaults to `"rladies"`.

- onboarding_repo:

  Repository holding onboarding issues.

## Value

The posted body (invisibly).
