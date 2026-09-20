# Open a proposed challenge issue in the review repo

Creates a `status: proposed` issue in the challenge repo (default
`rladies/cauldron`) from a verified draft, labelled with its source and
its themed difficulty, ready for an organiser to review. Requires a
`GITHUB_PAT`/`GITHUB_TOKEN` with `issues: write` on the target repo.

## Usage

``` r
r_challenge_open_issue(build, repo = "rladies/cauldron", source = "ai")
```

## Arguments

- build:

  Result of
  [`r_challenge_draft_build()`](https://rladies.github.io/jinx/reference/r_challenge_draft_build.md).

- repo:

  Target review repo as `"owner/name"`.

- source:

  Where the challenge came from, e.g. `"ai"`.

## Value

The created issue's URL, invisibly.
