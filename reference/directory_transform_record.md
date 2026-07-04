# Transform a single Airtable submission into a directory entry.

Returns `NULL` for ineligible records (default rows,
non-minority-gender, or missing a usable slug). Delete requests return
early with just `slug` and `delete = TRUE`. Otherwise returns a list
with the target `slug`, the submitted entry `data` (only fields the
submitter provided), the `email` for the contact file, `photo` download
metadata, and `clear_fields`.

## Usage

``` r
directory_transform_record(record, lookups)
```
