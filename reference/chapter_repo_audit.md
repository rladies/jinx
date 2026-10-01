# Audit the GitHub references in chapter data

Each chapter may carry a `social_media$github` value. Two shapes are
legitimate: `owner/repo` for a chapter that keeps its files in a
repository, and a bare organisation name for a chapter that runs its own
GitHub organisation. Anything that resolves to neither is a dead link on
the chapter's page.

## Usage

``` r
chapter_repo_audit(chapters_dir, org = "rladies")
```

## Arguments

- chapters_dir:

  Directory of chapter JSON files.

- org:

  Organisation the conventional repository would live in.

## Value

A data frame with columns `file`, `github`, `state` and `suggestion`.
`state` is `"repo"`, `"org"`, `"url"`, `"prefixed"` or `"missing"`. A
`"url"` row resolves but is written as a full URL; a `"prefixed"` row is
an organisation the chapter owns, written as though it were a repository
under `org`. Both carry the same reference in the expected shape as
their suggestion. Only rows needing attention are returned.

## Details

Where a reference is dead and the conventional
`<org>/meetup-presentations_<city>` repository exists, that is reported
as the likely correction.
