# Provision a chapter mailbox once a human has approved it

Reads the chapter from the onboarding issue's own machine-readable
block, checks that a member of an approving team has left an approval
comment, and only then asks the worker to create the mailbox. The
address is posted back on the issue and the email step of the checklist
is ticked.

## Usage

``` r
chapter_email_provision(
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

The created address (invisibly).

## Details

The approval is a separate, deliberate act on the specific issue: being
allowed to run the command is not on its own enough to create an
account, so a stray dispatch or a mistaken command cannot provision
anything.
