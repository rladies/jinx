# Subscribe an RSS feed to a Slack channel

Posts a `/feed subscribe` command to the specified Slack channel using
the Slack API.

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
