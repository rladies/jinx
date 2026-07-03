# Summon a GitHub Copilot review on a pull request

Requests Copilot as a reviewer and posts a short scoping comment naming
the grimoire gate. Copilot then applies the instruction files synced by
[`copilot_sync_repo()`](https://rladies.github.io/jinx/reference/copilot_sync_repo.md).
Returns a status message suitable for replying to the requester.

## Usage

``` r
copilot_review_pr(
  owner,
  repo,
  pr_number,
  gate = NULL,
  comment = TRUE,
  config = load_copilot_review_config()
)
```

## Arguments

- owner:

  Repository owner.

- repo:

  Repository name.

- pr_number:

  Pull request number.

- gate:

  Gate key (`brand`, `blog`, `social`, `translation`), or `NULL` for a
  full review.

- comment:

  Whether to post the scoping comment. Defaults to `TRUE`.

- config:

  Config from
  [`load_copilot_review_config()`](https://rladies.github.io/jinx/reference/load_copilot_review_config.md).

## Value

A status string.
