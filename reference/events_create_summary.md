# Create a formatted event summary

Create a formatted event summary

## Usage

``` r
events_create_summary(events, period = c("weekly", "monthly"))
```

## Arguments

- events:

  Data frame from
  [`events_list_chapter()`](https://rladies.github.io/jinx/reference/events_list_chapter.md)
  or
  [`events_sync_chapters()`](https://rladies.github.io/jinx/reference/events_sync_chapters.md).

- period:

  Summary period label.

## Value

Formatted markdown string.
