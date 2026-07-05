# Gather chunks from a meetup events JSON feed

Reads an array of meetup events, drops cancelled events and past events
older than `past_window_seconds`, and emits one chunk per remaining
event plus a single cross-chapter digest of every upcoming event (see
[`events_digest_chunk()`](https://rladies.github.io/jinx/reference/events_digest_chunk.md)).
Required `src` fields: `url`, `repo`.

## Usage

``` r
gather_events_json(
  src,
  past_window_seconds = src$past_window_seconds %or% (365L * 24L * 60L * 60L),
  min_chars = src$min_chars %or% 80L
)
```

## Arguments

- src:

  Source spec list.

- past_window_seconds:

  Drop `past` events older than this many seconds before now.

- min_chars:

  Drop chunks shorter than this many characters.

## Value

List of chunk records.
