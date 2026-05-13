# Sync events across all chapters

Fetches events from all configured sources and writes a summary.

## Usage

``` r
events_sync_chapters(
  org = "rladies",
  target_repo = "event-archive",
  months = 3,
  dry_run = TRUE
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

## Value

Data frame of all events (invisibly).
