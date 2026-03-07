# List events for a chapter

Queries Meetup Pro for recent events.

## Usage

``` r
list_chapter_events(chapter, months = 3)
```

## Arguments

- chapter:

  Chapter identifier (e.g. "rladies-berlin").

- months:

  Number of months of history.

## Value

Data frame with columns: title, date, url, rsvp_count, source, chapter.
