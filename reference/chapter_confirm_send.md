# Confirm a completed onboarding to the chapter organisers

Sends the confirmation email from `jinx@rladies.org`, cc'ing
`chapters@rladies.org` so the onboarding inbox keeps the thread, and
notes on the issue that it went out.

## Usage

``` r
chapter_confirm_send(
  issue_number,
  to,
  city = NULL,
  email = NULL,
  meetup_url = NULL,
  force = FALSE,
  org = "rladies",
  onboarding_repo = "new-chapters-onboarding"
)
```

## Arguments

- issue_number:

  Onboarding issue number.

- to:

  Organiser email addresses.

- city:

  Chapter city. Read from the issue when `NULL`.

- email:

  Chapter email address to quote in the message.

- meetup_url:

  Meetup URL to quote in the message.

- force:

  Send even with checklist steps outstanding.

- org:

  GitHub organization. Defaults to `"rladies"`.

- onboarding_repo:

  Repository holding onboarding issues.

## Value

The sent message id (invisibly).

## Details

Refuses to send while checklist steps are outstanding, since the email
tells the organisers their chapter is set up. Pass `force = TRUE` to
override, which is occasionally right - a step may be recorded
elsewhere - but it should be a decision rather than an accident.

Recipient addresses are passed in rather than read from the issue:
organiser emails are deliberately not stored in the issue metadata, and
this function does not put them back there either. The issue comment
records how many organisers were written to, not who.
