# Generate and update a contributors list for a repo

Fetches contributors and creates/updates a PR with the contributor list
in a specified file.

## Usage

``` r
contributors_update(
  owner,
  repo,
  file_path = ".github/contributors.md",
  format = "grid"
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

## Value

PR URL if changes were made, `NULL` otherwise (invisibly).
