# Find the approvals on a chapter onboarding issue

An approval is a comment containing the approval marker, written by a
confirmed member of an approving team. Bot comments never count, so jinx
cannot approve its own work.

## Usage

``` r
chapter_email_approvals(
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

Character vector of approver logins, possibly empty.
