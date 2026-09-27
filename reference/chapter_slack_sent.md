# Record that the organisers Slack invite was sent

Record that the organisers Slack invite was sent

## Usage

``` r
chapter_slack_sent(
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

`TRUE` when the checklist step was ticked.
