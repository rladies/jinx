# Create a formatted event summary

Create a formatted event summary

## Usage

``` r
event_create_summary(events, period = c("weekly", "monthly"))
```

## Arguments

- events:

  Data frame from
  [`event_list_chapter()`](https://rladies.github.io/jinx/reference/event_list_chapter.md)
  or
  [`event_sync_chapters()`](https://rladies.github.io/jinx/reference/event_sync_chapters.md).

- period:

  Summary period label.

## Value

Formatted markdown string.
