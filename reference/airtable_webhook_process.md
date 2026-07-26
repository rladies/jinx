# Process an Airtable invite-request webhook

The `airtable_webhook` event handler registered in `jinx_events()`.
Checks the base is within the configured Airtable token's scope, builds
the approval-request card, and posts it to the community-invite channel.
R port of the remainder of `airtable_webhook_handle()` (after
shared-secret verification, which stays in the Worker) from the deleted
`worker/src/airtable-invite.js`.

## Usage

``` r
airtable_webhook_process(
  email,
  name = NULL,
  chapter = NULL,
  record_id,
  base_id,
  table_id,
  channel = Sys.getenv("SLACK_COMMUNITY_INVITE_CHANNEL")
)
```

## Arguments

- email:

  Applicant email.

- name:

  Applicant name, or `NULL`.

- chapter:

  Chapter name, or `NULL`.

- record_id:

  Airtable record ID.

- base_id:

  Airtable base ID.

- table_id:

  Airtable table ID.

- channel:

  Slack channel to post the request to. Defaults to env
  `SLACK_COMMUNITY_INVITE_CHANNEL`.

## Value

Invisibly, `TRUE` if posted, `FALSE` if the base was rejected.
