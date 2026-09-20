# Set up a Slack channel with RLadies+ bookmarks

The `"setup-channel"` command handler: joins the channel if needed
(public channels only - a private channel requires a human invite
first), then adds any bookmarks from `inst/config/bookmarks.json` the
channel doesn't already have. R port of `slash_setup_channel()` from the
deleted `worker/src/slash-local.js`; reads the bookmarks config directly
from this package's `inst/` instead of the Worker's redundant GitHub-raw
fetch of the same file.

## Usage

``` r
setup_channel_process(team_id, channel_id, channel_name)
```

## Arguments

- team_id:

  Slack team id.

- channel_id:

  Channel to set up.

- channel_name:

  Channel display name, for the reply text.

## Value

Character scalar reply text.
