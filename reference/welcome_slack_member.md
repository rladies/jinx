# Welcome a new member to an RLadies+ Slack workspace

Sends a direct message to the given Slack user introducing them to the
workspace, pointing them to the Code of Conduct, the welcome channel,
and a starter set of channels to explore. Two templates are available:
one for the RLadies+ Community Slack, one for the RLadies+ Organisers
Slack.

## Usage

``` r
welcome_slack_member(
  user_id,
  workspace = c("community", "organisers"),
  coc_url = "https://rladies.org/about/coc/",
  welcome_channel = NULL,
  help_channel = NULL,
  starter_channels = NULL,
  token = Sys.getenv("SLACK_TOKEN")
)
```

## Arguments

- user_id:

  Slack user ID (e.g. `"U12345"`).

- workspace:

  One of `"community"` or `"organisers"`. Selects which template and
  default channel set is used.

- coc_url:

  URL to the RLadies+ Code of Conduct.

- welcome_channel:

  Channel name (no `#`) where new members introduce themselves. Defaults
  to `"welcome"`.

- help_channel:

  Channel name (no `#`) where workspace questions can be asked.
  Workspace-specific default.

- starter_channels:

  List of starter channels, each a list with `name` and `desc`. Defaults
  to
  [`default_welcome_channels()`](https://rladies.github.io/jinx/reference/default_welcome_channels.md)
  for the chosen workspace.

- token:

  Slack API token. Defaults to `Sys.getenv("SLACK_TOKEN")`.

## Value

API response (invisibly).

## Details

The function is stateless: jinx does not persist any user identifiers.
The Slack `team_join` event is the source of truth for who to welcome –
see the `slack-welcome.yml` GitHub Actions workflow (`workflow_dispatch`
/ `repository_dispatch` triggered by the Slack event handler) for the
wiring.
