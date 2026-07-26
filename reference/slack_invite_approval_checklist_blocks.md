# Build the post-approval checklist Block Kit card

R port of `slack_invite_approval_checklist_blocks()` from the deleted
`worker/src/airtable-invite.js`.

## Usage

``` r
slack_invite_approval_checklist_blocks(
  email,
  approver,
  record_id,
  base_id,
  table_id
)
```

## Arguments

- email:

  Applicant email.

- approver:

  Slack username who approved the request.

- record_id:

  Airtable record ID.

- base_id:

  Airtable base ID.

- table_id:

  Airtable table ID.

## Value

A list of Block Kit blocks.
