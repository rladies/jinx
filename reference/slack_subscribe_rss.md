# Post a request to subscribe an RSS feed to a Slack channel

Slack only runs slash commands typed by a real user, so a bot cannot
subscribe a feed directly. This posts an actionable request asking a
human in the channel to run `/feed subscribe <url>`.

## Usage

``` r
slack_subscribe_rss(
  rss_url,
  channel = "rladiesblogs",
  token = Sys.getenv("SLACK_TOKEN")
)
```

## Arguments

- rss_url:

  RSS feed URL to subscribe.

- channel:

  Slack channel name (without \#). Defaults to "rladiesblogs".

- token:

  Slack API token.

## Value

API response (invisibly).
