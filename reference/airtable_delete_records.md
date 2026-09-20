# Delete Airtable records by id, one request each.

Used by the GDPR purge. A per-record `DELETE` keeps it simple and robust
for the small counts a purge touches; the caller re-derives the id list
from a fresh listing, so a re-run never re-deletes an already-gone
record.

## Usage

``` r
airtable_delete_records(base_id, table, record_ids, api_key)
```
