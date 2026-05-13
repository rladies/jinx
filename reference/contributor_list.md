# List contributors for a repository

Collects all contributors from merged PRs and commits, returning a
deduplicated list with contribution counts.

## Usage

``` r
contributor_list(owner, repo, include_bots = FALSE)
```

## Arguments

- owner:

  Repository owner.

- repo:

  Repository name.

- include_bots:

  Whether to include bot accounts. Defaults to `FALSE`.

## Value

Data frame with `login`, `contributions`, `avatar_url`, and
`profile_url` columns, sorted by contribution count.
