# Send reminders on stale global team onboarding/offboarding issues

Finds open issues with onboarding or offboarding labels that haven't
been updated in `days` days, and posts a reminder comment.

## Usage

``` r
global_team_remind_stale(org = "rladies", days = 30, repo = "global-team")
gt_remind_stale(org = "rladies", days = 30, repo = "global-team")
```

## Arguments

- org:

  GitHub organization. Defaults to `"rladies"`.

- days:

  Number of days without activity before reminding. Defaults to 30.

- repo:

  Repository to check. Defaults to `"global-team"`.

## Value

Invisibly returns `NULL`. Called for its side effect of posting reminder
comments on stale issues.
