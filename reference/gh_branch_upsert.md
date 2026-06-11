# Create or reset a branch to match a base ref

Reads the base branch tip and either creates `branch` there or
force-updates it. Used by helpers that need to (re-)open a clean working
branch before pushing files.

## Usage

``` r
gh_branch_upsert(org, repo, branch, base = "main", force = TRUE)
```

## Arguments

- org:

  Repository owner.

- repo:

  Repository name.

- branch:

  Branch to create or update.

- base:

  Base branch whose tip is used as the new SHA. Defaults to `"main"`.

- force:

  Whether to force-update if the branch already exists. Defaults to
  `TRUE`.

## Value

The SHA the branch now points to (invisibly).
