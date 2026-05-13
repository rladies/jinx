# Request a Slack invitation for someone not yet on the workspace

The bot cannot invite users directly (Slack admin scopes are not
available to community apps). Instead, this function posts a message to
an organisers' Slack channel with the email address and instructions for
a workspace admin to action the invite manually, then flips the matching
Airtable record's `invited` flag for audit.

## Usage

``` r
slack_invite_request(
  email,
  channel = Sys.getenv("SLACK_INVITE_REQUEST_CHANNEL"),
  base_id = slack_invitees_base_id(),
  api_key = Sys.getenv("AIRTABLE_API_KEY"),
  token = Sys.getenv("SLACK_TOKEN")
)
```

## Arguments

- email:

  Email address to request an invite for.

- channel:

  Slack channel where the request is posted. Defaults to
  `SLACK_INVITE_REQUEST_CHANNEL` env var, falling back to
  `"global-team"`.

- base_id:

  Airtable base ID for Slack invitees.

- api_key:

  Airtable API key. If unset, the Airtable audit step is skipped.

- token:

  Slack bot token (`chat:write` scope is enough).

## Value

A single status string suitable for posting back as a PR comment.
