# Sync directory entries from Airtable

Fetches directory submissions from Airtable, transforms each eligible
record into the directory entry schema, and opens (or updates) a PR on
the directory repo containing only the entries whose content changed.

## Usage

``` r
directory_sync_airtable(
  base_id = directory_base_id(),
  api_key = Sys.getenv("AIRTABLE_API_KEY"),
  org = "rladies",
  directory_repo = "directory"
)
```

## Arguments

- base_id:

  Airtable base ID. Defaults to the directory base.

- api_key:

  Airtable API key. Defaults to `AIRTABLE_API_KEY` env var.

- org:

  GitHub organization. Defaults to `"rladies"`.

- directory_repo:

  Directory repository name.

## Value

PR URL if changes found, `NULL` otherwise (invisibly).

## Details

Only submissions marked `minority_gender == "yes"` and not flagged as a
`DEFAULT ROW` are processed. Returning submitters are matched to their
existing entry by slug (`directory_id`, falling back to `identifier`),
and their submission is merged onto the existing file: fields listed in
`clear_fields` are wiped first, then submitted fields overlay the rest,
so a partial update never drops data the submitter left blank.

Delete requests are collected and reported in the PR body but are
**not** executed here; destructive removal stays with the reviewed purge
workflow.
