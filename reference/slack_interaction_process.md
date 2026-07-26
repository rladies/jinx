# Process a Slack interaction from the invite-approval flow

The `slack_interaction` event handler registered in `jinx_events()`.
Branches on `action_id` exactly like the three JS functions it replaces
(`slack_invite_process_approval`/`_sent`/`_denial`, deleted from
`worker/src/airtable-invite.js`), replying via `response_url` for each.

## Usage

``` r
slack_interaction_process(action_id, action_data, admin_user, response_url)
```

## Arguments

- action_id:

  One of `"invite_approve"`, `"invite_deny"`, `"invite_mark_sent"`.

- action_data:

  Parsed button `value` payload: `email`, `record_id`, `base_id`,
  `table_id`, and (for approve replies) `approver`.

- admin_user:

  Slack username who clicked the button.

- response_url:

  The interaction's `response_url`.

## Value

Invisibly, `NULL`.
