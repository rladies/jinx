# Send pending Slack invitations

Fetches pending invitees from Airtable and prepares invite emails with a
Slack invitation link.

## Usage

``` r
send_slack_invites(
  invite_link,
  base_id = slack_invitees_base_id(),
  api_key = Sys.getenv("AIRTABLE_API_KEY"),
  sender_name = "R-Ladies Global",
  sender_email = "info@rladies.org",
  dry_run = TRUE
)
```

## Arguments

- invite_link:

  Active Slack invite URL (valid for 30 days).

- base_id:

  Airtable base ID for Slack invitees.

- api_key:

  Airtable API key.

- sender_name:

  Name of the sender.

- sender_email:

  Sender email address.

- dry_run:

  If `TRUE` (default), only returns prepared emails.

## Value

Data frame of prepared emails (invisibly).
