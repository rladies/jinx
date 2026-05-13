# Check CFP deadlines and post reminders

Check CFP deadlines and post reminders

## Usage

``` r
cfp_check_deadlines(org = "rladies", repo = "global-team", warn_days = 7)
```

## Arguments

- org:

  GitHub organization.

- repo:

  Repository where CFP issues are tracked.

- warn_days:

  Number of days before deadline to warn.

## Value

Data frame of approaching CFPs (invisibly).
