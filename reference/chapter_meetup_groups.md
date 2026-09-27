# Chapters that have a Meetup group, read from the website data

The website's `data/chapters` entries are the source of truth for which
chapters exist and which Meetup group each uses, so the sync derives its
list from there rather than from a hand-maintained one that would drift
the day it was written.

## Usage

``` r
chapter_meetup_groups(
  org = "rladies",
  website_repo = "rladies.github.io",
  statuses = c("active", "prospective")
)
```

## Arguments

- org:

  GitHub organization. Defaults to `"rladies"`.

- website_repo:

  Repository holding `data/chapters`.

- statuses:

  Chapter statuses to include.

## Value

A data frame with columns `file`, `city`, `country`, `status`, and
`urlname`.

## Details

Retired chapters are excluded by default: they have no upcoming events
and querying them only spends requests.
