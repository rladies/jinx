# Gather chunks from a YouTube channel's uploads playlist

Requires `YOUTUBE_API_KEY` in the environment. Pages through every video
in the channel's uploads playlist and emits one chunk per video (title +
description). Required `src` fields: `channel_id`, `repo`.

## Usage

``` r
gather_youtube_channel(
  src,
  max_description_chars = src$max_description_chars %or% 4000L
)
```

## Arguments

- src:

  Source spec list.

- max_description_chars:

  Cap on bytes of description kept per video.

## Value

List of chunk records.
