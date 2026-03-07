# List events from the Meetup GraphQL API

List events from the Meetup GraphQL API

## Usage

``` r
meetup_list_events(
  group_urlname,
  months = 3,
  api_key = Sys.getenv("MEETUP_API_KEY")
)
```

## Arguments

- group_urlname:

  Meetup group URL name (e.g. "rladies-berlin").

- months:

  Number of months of history to fetch.

- api_key:

  Meetup Pro API key. Defaults to `MEETUP_API_KEY` env var.

## Value

Data frame with columns: title, date, url, rsvp_count, source, chapter.
