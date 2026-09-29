# Reconcile stored chapter status against actual Meetup activity

The website's `status` field is set by hand, so it drifts from what the
chapters are actually doing. This compares it against the event history
in `meetup_archive` and reports the two mismatches worth acting on: a
chapter running events that is not marked active, and a chapter marked
active that has gone quiet.

## Usage

``` r
chapter_status_reconcile(
  chapters_dir,
  health = NULL,
  months = 6,
  retire_months = 12,
  initiated = NULL
)
```

## Arguments

- chapters_dir:

  Directory of chapter JSON files, typically `data/chapters` in the
  website repository.

- health:

  Output of
  [`chapter_check_health()`](https://rladies.github.io/jinx/reference/chapter_check_health.md),
  or `NULL` to fetch it. Passed in to avoid refetching when reconciling
  repeatedly.

- months:

  Months without an event before a chapter is flagged. Defaults to 6,
  matching the guide.

- retire_months:

  Months without an event before a chapter should simply be marked
  inactive. Defaults to 12.

- initiated:

  Optional `Date` vector, one per file in `chapters_dir`, from
  [`chapter_initiated_date()`](https://rladies.github.io/jinx/reference/chapter_initiated_date.md).
  A chapter younger than `retire_months` is never marked inactive,
  because it has not had time to run anything yet. `NA` counts as old
  enough.

## Value

A data frame with one row per chapter that has a `urlname`,

A data frame with one row per chapter, with columns `file`, `urlname`,
`stored`, `last_event`, `months_inactive` and `action`. `action` is
`"promote to active"`, `"flag quiet"`, `"mark inactive"`, or `NA` when
nothing needs doing.

## Details

The categories follow the guide: a chapter is active when it has run an
event in the last `months`, and inactive when it has not.

Chapters create their events on Meetup even when they promote them
elsewhere, precisely so activity can be tracked, so an absence of Meetup
events is a real signal rather than an artefact of where a chapter
advertises. That holds for every chapter, so one with no Meetup group at
all is included here rather than skipped: having no group means it never
began, or stopped before it started.
