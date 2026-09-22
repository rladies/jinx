# Open a PR, or return the existing open PR for a branch

If a PR is already open from `branch` into `base`, returns its URL;
otherwise opens a new PR with the given title and body.

## Usage

``` r
gh_open_or_update_pr(
  org,
  repo,
  branch,
  base = "main",
  title,
  body,
  team_reviewers = NULL
)
```

## Arguments

- org:

  Repository owner.

- repo:

  Repository name.

- branch:

  Head branch.

- base:

  Base branch. Defaults to `"main"`.

- title:

  PR title.

- body:

  PR body.

- team_reviewers:

  Character vector of org team slugs to request review from, or `NULL`
  for none.

## Value

PR URL.
