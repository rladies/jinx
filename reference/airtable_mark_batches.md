# Split record ids into Airtable PATCH payloads of at most 10 records.

Each payload sets `field` to `TRUE` on its records, ready for
[`httr2::req_body_json()`](https://httr2.r-lib.org/reference/req_body.html).

## Usage

``` r
airtable_mark_batches(record_ids, field)
```
