# Check chapter health across the organization

Identifies chapters that have been inactive (no events) for a specified
number of months.

## Usage

``` r
check_chapter_health(
  months = 12,
  org = "rladies",
  data_repo = "meetup_archive"
)
```

## Arguments

- months:

  Number of months without activity to consider inactive. Defaults to
  12.

- org:

  GitHub organization. Defaults to `"rladies"`.

- data_repo:

  Repository containing chapter/event data. Defaults to
  `"meetup_archive"`.

## Value

A data frame with columns `chapter`, `last_event`, `status`, and
`months_inactive`.
