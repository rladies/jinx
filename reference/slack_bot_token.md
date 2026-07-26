# Resolve the bot token for a jinx-operated Slack workspace

R/GitHub Actions only ever operates in two known workspaces (organiser,
community) via two static secrets, unlike the Worker's per-team
OAuth-token KV store which supports arbitrary installs - jinx isn't
installed anywhere else, so the simpler static lookup is enough.

## Usage

``` r
slack_bot_token(workspace = c("organiser", "community"))
```

## Arguments

- workspace:

  Either `"organiser"` or `"community"`.

## Value

The bot token string.
