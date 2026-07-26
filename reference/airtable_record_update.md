# Update fields on an Airtable record

R's first Airtable write primitive - everything in `R/airtable-sync.R`
is read-only. R port of `airtable_record_update()` from the deleted
`worker/src/airtable-invite.js`.

## Usage

``` r
airtable_record_update(
  base_id,
  table_id,
  record_id,
  fields,
  api_key = Sys.getenv("AIRTABLE_API_KEY")
)
```

## Arguments

- base_id:

  Airtable base ID.

- table_id:

  Airtable table ID.

- record_id:

  Airtable record ID.

- fields:

  Named list of fields to update.

- api_key:

  Airtable API key. Defaults to env `AIRTABLE_API_KEY`.

## Value

Invisibly, `TRUE`.
