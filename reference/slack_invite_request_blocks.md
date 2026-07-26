# Build the initial Slack invite-request Block Kit card

R port of `slack_invite_request_blocks()` from the deleted
`worker/src/airtable-invite.js`. `chapter` is shown but, matching the JS
original, deliberately not carried in the button `value` payload.

## Usage

``` r
slack_invite_request_blocks(email, name, chapter, record_id, base_id, table_id)
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

## Value

A list of Block Kit blocks.
