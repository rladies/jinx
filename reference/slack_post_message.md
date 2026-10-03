# Post a message to a Slack channel

Sends a markdown-formatted message to the specified Slack channel using
the Slack Web API.

## Usage

``` r
slack_post_message(
  text,
  channel,
  token = Sys.getenv("SLACK_TOKEN"),
  unfurl = FALSE
)
```

## Arguments

- text:

  Message text (supports Slack mrkdwn formatting).

- channel:

  Slack channel name (without \#).

- token:

  Slack API token. Defaults to `Sys.getenv("SLACK_TOKEN")`.

- unfurl:

  Whether Slack may expand links into previews. Off by default: most of
  what Jinx posts links to an issue or a chapter page, where a preview
  card adds noise. Messages whose whole point is the linked page
  (community blog posts) turn it on.

## Value

API response (invisibly).
