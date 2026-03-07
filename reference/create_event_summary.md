# Create a formatted event summary

Create a formatted event summary

## Usage

``` r
create_event_summary(events, period = c("weekly", "monthly"))
```

## Arguments

- events:

  Data frame from
  [`list_chapter_events()`](https://rladies.github.io/jinx/reference/list_chapter_events.md)
  or
  [`sync_chapter_events()`](https://rladies.github.io/jinx/reference/sync_chapter_events.md).

- period:

  Summary period label.

## Value

Formatted markdown string.
