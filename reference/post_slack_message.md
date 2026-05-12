# Post a message to a Slack channel

Sends a markdown-formatted message to the specified Slack channel using
the Slack Web API.

## Usage

``` r
post_slack_message(text, channel, token = Sys.getenv("SLACK_TOKEN"))
```

## Arguments

- text:

  Message text (supports Slack mrkdwn formatting).

- channel:

  Slack channel name (without \#).

- token:

  Slack API token. Defaults to `Sys.getenv("SLACK_TOKEN")`.

## Value

API response (invisibly).
