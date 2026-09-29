# When a chapter first appeared in the website repository

Used as the start of the six-month window in which a chapter with no
events counts as unbegun rather than inactive.

## Usage

``` r
chapter_initiated_date(files, repo = ".", bulk_import = as.Date("2023-01-04"))
```

## Arguments

- files:

  Chapter file paths, relative to `repo`.

- repo:

  Path to the website repository.

- bulk_import:

  Date of the bulk import to treat as unknown, or `NULL` to keep every
  date.

## Value

A `Date` vector, `NA` where the date is unknown or untrusted.

## Details

Two things make this fragile, and both are handled here. Renaming a
chapter file would otherwise reset its date to the rename, so the lookup
follows renames. A shallow clone has no history to read, so the caller's
checkout needs `fetch-depth: 0`; without it every chapter looks as
though it appeared today.

Dates before `bulk_import` are not meaningful: 118 chapters were added
to the website in one import on 2023-01-04, so that date records the
import rather than when any of those chapters started. Those come back
as `NA`.
