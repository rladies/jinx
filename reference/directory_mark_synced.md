# Flag handled submissions as synced.

Reconciles Airtable against the directory and flips the
[`directory_synced_field()`](https://rladies.github.io/jinx/reference/directory_synced_field.md)
checkbox on every submission whose work is done, so future syncs skip
it:

## Usage

``` r
directory_mark_synced(
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

Character vector of marked record ids (invisibly).

## Details

- an **update** is done once applying it to `main` would change nothing
  — its entry is already fully incorporated (the same predicate the sync
  uses to decide whether to commit);

- a **delete request** is done once its entry file is absent from `main`
  — the reviewed purge workflow has removed it.

Stateless and idempotent — safe to run on every sync-PR merge and after
a purge completes.
