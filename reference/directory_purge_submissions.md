# Erase every Airtable submission for the given directory slugs.

GDPR right-to-erasure: after the purge workflow removes a member's entry
from the directory, every `submissions` row that resolves to one of
`slugs` (by `directory_id`, falling back to `identifier`) is **deleted**
from Airtable so no submitted PII remains — and so a later sync cannot
re-create the entry from a leftover row. Unlike
[`directory_mark_synced()`](https://rladies.github.io/jinx/reference/directory_mark_synced.md),
which only flags the `synced` checkbox, this destroys the rows.

## Usage

``` r
directory_purge_submissions(
  slugs,
  base_id = directory_base_id(),
  api_key = Sys.getenv("AIRTABLE_API_KEY")
)
```

## Arguments

- slugs:

  Character vector of directory slugs to erase.

- base_id:

  Airtable base ID. Defaults to the directory base.

- api_key:

  Airtable API key. Defaults to the `AIRTABLE_API_KEY` env var.

## Value

Character vector of deleted record ids (invisibly).
