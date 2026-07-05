# Build one cross-chapter digest chunk of all upcoming events

Vector search over per-event chunks cannot answer "when is the next
event, regardless of chapter" — upcoming-ness is a structured filter,
not a semantic property, and only a handful of events are upcoming at
any time. This emits a single `events-digest` chunk listing every
upcoming event across all chapters, soonest first, so retrieval has a
complete global view to answer from. Returns `NULL` when nothing is
upcoming.

## Usage

``` r
events_digest_chunk(
  ev_list,
  src,
  max_events = src$digest_max_events %or% 30L,
  landing_url = src$digest_url %or% "https://rladies.org/events/"
)
```

## Arguments

- ev_list:

  Full list of raw event records.

- src:

  Source spec list.

- max_events:

  Cap the number of events rendered into the digest.

- landing_url:

  Canonical URL for the full events listing.

## Value

A chunk record, or `NULL`.
