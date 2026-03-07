# Monitor chapter activity status

Determines chapter status based on meetup event data. Chapters are
classified as active, inactive, or unbegun based on their last event and
founding date.

## Usage

``` r
monitor_chapter_status(data_path = NULL, inactive_months = 6, org = "rladies")
```

## Arguments

- data_path:

  Path to a CSV export from Meetup Pro Dashboard, or `NULL` to fetch
  from meetup_archive.

- inactive_months:

  Months without events to consider inactive. Defaults to 6.

- org:

  GitHub organization.

## Value

Data frame with chapter status information.
