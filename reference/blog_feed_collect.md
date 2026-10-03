# Collect every recent post across the curated feeds

Polls each source in turn, keeping going when an individual feed is down
so one dead blog can't silence the rest, then returns the items sorted
oldest first so a channel reads in publication order.

## Usage

``` r
blog_feed_collect(
  entries = NULL,
  max_age_days = 14,
  now = as.numeric(Sys.time())
)
```

## Arguments

- entries:

  Curated content entries. Fetched when `NULL`.

- max_age_days:

  Only announce items published within this window.

- now:

  Current time, as a unix timestamp.

## Value

A list with `posts` (a list of `item`/`source` pairs, oldest first),
`feedless` (titles with no `rss_feed`), and `sources` (how many feeds
were polled).

## Details

Deliberately knows nothing about what any workspace has already
announced: both blog channels want the same posts, so a run polls the
feeds once and each workspace filters the result against its own
seen-set with
[`blog_feed_pending()`](https://rladies.github.io/jinx/reference/blog_feed_pending.md).
Polling per workspace would double the requests every contributor's blog
receives.
