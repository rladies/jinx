# Generate and update a contributors list for a repo

Fetches contributors and commits the rendered list directly to the
default branch. No PR is opened.

## Usage

``` r
contributor_update(
  owner,
  repo,
  file_path = ".github/contributors.md",
  format = "grid",
  branch = "main"
)
```

## Arguments

- owner:

  Repository owner.

- repo:

  Repository name.

- file_path:

  Path in the repo to update with the contributor list. Defaults to
  `".github/contributors.md"`.

- format:

  Format for the contributor list.

- branch:

  Branch to commit to. Defaults to `"main"`.

## Value

Commit URL if changes were made, `NULL` otherwise (invisibly).
