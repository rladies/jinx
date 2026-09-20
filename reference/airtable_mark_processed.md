# Mark Airtable records as processed.

PATCHes each record's boolean `field` to `TRUE`, in batches of 10 (the
Airtable write limit). Called after a sync PR merges to flag the
submissions whose entries are now live in the directory, so subsequent
syncs skip them.

## Usage

``` r
airtable_mark_processed(
  base_id,
  table,
  record_ids,
  api_key,
  field = directory_synced_field()
)
```
