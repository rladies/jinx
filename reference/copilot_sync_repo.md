# Sync grimoire review skills into a repo as Copilot instructions

Fetches the four grimoire review-gate skills (plus the foundation brand
ruleset) and lands them in `owner/repo` as
`.github/copilot-instructions.md` and path-scoped
`.github/instructions/*.instructions.md` files, via a pull request. This
is what makes GitHub Copilot's code review grimoire-aware. Re-run
whenever grimoire changes to refresh the instructions.

## Usage

``` r
copilot_sync_repo(
  owner = "rladies",
  repo,
  base = "main",
  branch = "jinx/copilot-review-instructions",
  config = load_copilot_review_config()
)
```

## Arguments

- owner:

  Target repository owner. Defaults to `"rladies"`.

- repo:

  Target repository name.

- base:

  Base branch. Defaults to `"main"`.

- branch:

  Working branch. Defaults to `"jinx/copilot-review-instructions"`.

- config:

  Config from
  [`load_copilot_review_config()`](https://rladies.github.io/jinx/reference/load_copilot_review_config.md).

## Value

A list with `status` (`"created"` or `"unchanged"`) and `url` (the PR
URL when created).
