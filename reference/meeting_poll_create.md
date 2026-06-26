# Create a meeting-scheduling poll on samkoma

Creates a "find a time" poll where participants paint their availability
over a set of days and time slots. Polls are public by default so
results can be read back without a stored secret; the returned
`edit_token` is the host secret needed to lock the final slot or read a
hidden poll.

## Usage

``` r
meeting_poll_create(
  title,
  days,
  from,
  to,
  slot,
  tz = "UTC",
  kind = c("dates", "weekdays"),
  public = TRUE,
  results_hidden = FALSE,
  deadline = NULL,
  base_url = samkoma_base_url()
)
```

## Arguments

- title:

  Poll title (1-200 characters).

- days:

  Character vector of day identifiers: ISO dates (`YYYY-MM-DD`) when
  `kind = "dates"`, or weekday names (`mon`..`sun`) when
  `kind = "weekdays"`. 1-60 items.

- from, to:

  Start and end of the daily window, `"HH:MM"` (24h).

- slot:

  Slot length in minutes.

- tz:

  IANA timezone name (e.g. `"Europe/Oslo"`). Defaults to UTC.

- kind:

  Either `"dates"` (default) or `"weekdays"`.

- public:

  Whether the poll is publicly readable. Defaults to `TRUE`.

- results_hidden:

  Whether responses are hidden from voters.

- deadline:

  Optional ISO 8601 datetime after which voting closes.

- base_url:

  API base URL.

## Value

A list with `id`, `url`, and `edit_token`.
