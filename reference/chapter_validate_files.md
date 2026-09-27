# Validate website chapter data files

Runs the checks that keep `data/chapters/*.json` on the website
consistent with the conventions jinx relies on elsewhere: the schema,
the filename derivation, and the agreement between `urlname` and
`social_media$meetup`.

## Usage

``` r
chapter_validate_files(paths, added = character())
```

## Arguments

- paths:

  Character vector of paths to chapter JSON files.

- added:

  Character vector of paths (a subset of `paths`) that the pull request
  adds rather than modifies. Filename mismatches are errors for added
  files and warnings for modified ones, because 32 files already in the
  repository predate the convention.

## Value

A data frame with columns `file`, `level` (`"error"` or `"warning"`),
`check`, and `message`. Zero rows when everything passes.

## Details

Designed to run over the files changed in a pull request, so that
pre-existing drift in untouched files does not block unrelated work.
