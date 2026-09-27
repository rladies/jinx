# Sync events across all chapters

Fetches events from all configured sources and writes a summary.

## Usage

``` r
event_sync_chapters(
  org = "rladies",
  target_repo = "event-archive",
  months = 3,
  dry_run = TRUE,
  chapters = NULL
)
```

## Arguments

- org:

  GitHub organization.

- target_repo:

  Repository for the event archive.

- months:

  Number of months of history.

- dry_run:

  If `TRUE`, print what would be synced without acting.

- chapters:

  Meetup urlnames to sync. Read from the website data when `NULL`.

## Value

Data frame of all events (invisibly).

## Details

The chapter list comes from the website's `data/chapters` entries via
[`chapter_meetup_groups()`](https://rladies.github.io/jinx/reference/chapter_meetup_groups.md),
not from configuration: that data is already the source of truth for
which chapters exist and which Meetup group each uses, and a
hand-maintained list would drift immediately.
