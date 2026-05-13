# Send inactivity warning emails

Identifies inactive chapters and prepares warning emails for organizers.

## Usage

``` r
prepare_inactivity_emails(chapters, template_path = NULL, dry_run = TRUE)
```

## Arguments

- chapters:

  Chapter status data from
  [`chapter_monitor_status()`](https://rladies.github.io/jinx/reference/chapter_monitor_status.md).

- template_path:

  Path to email template.

- dry_run:

  If `TRUE` (default), only returns the email data without sending.

## Value

Data frame of prepared emails (invisibly).
