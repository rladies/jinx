# Sync directory entries from Airtable

Fetches directory entries from Airtable and updates the directory repo.
Creates a PR with new/updated entries for review.

## Usage

``` r
sync_directory_airtable(
  base_id = "appM6GuE0Jl1UI9qx",
  api_key = Sys.getenv("AIRTABLE_API_KEY"),
  org = "rladies",
  directory_repo = "directory"
)
```

## Arguments

- base_id:

  Airtable base ID.

- api_key:

  Airtable API key. Defaults to `AIRTABLE_API_KEY` env var.

- org:

  GitHub organization. Defaults to `"rladies"`.

- directory_repo:

  Directory repository name.

## Value

PR URL if changes found, `NULL` otherwise (invisibly).
