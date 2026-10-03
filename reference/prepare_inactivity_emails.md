# Prepare the guide's first inactivity notice for inactive chapters

Identifies inactive chapters and prepares the notice the guide documents
for them. The wording and the subject line come from the guide, fetched
at call time, so the message organisers receive is the one a volunteer
can edit there.

## Usage

``` r
prepare_inactivity_emails(
  chapters,
  template = "chapter-inactive-first-notice",
  dry_run = TRUE
)
```

## Arguments

- chapters:

  Chapter status data from
  [`chapter_monitor_status()`](https://rladies.github.io/jinx/reference/chapter_monitor_status.md).

- template:

  Name of the guide template to send. Defaults to the first inactivity
  notice; the guide also documents a retirement notice
  (`"chapter-retirement-scheduled"`) for chapters that do not reply.

- dry_run:

  Controls the wording of the summary only. Either way the prepared
  emails are returned rather than sent: delivery goes through
  [`mail_send()`](https://rladies.github.io/jinx/reference/mail_send.md),
  which a human still drives.

## Value

Data frame of prepared emails, one row per inactive chapter, with
`chapter`, `email`, `subject` and `body` (invisibly).
