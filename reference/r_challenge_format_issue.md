# Format a drafted challenge as a GitHub review issue

Builds the Markdown body an organiser reviews before approving: the
rendered statement in the open, with the reference solution, reprex
verification output, and adversarial notes in collapsed sections.

## Usage

``` r
r_challenge_format_issue(build, source = "ai")
```

## Arguments

- build:

  Result of
  [`r_challenge_draft_build()`](https://rladies.github.io/jinx/reference/r_challenge_draft_build.md).

- source:

  Where the challenge came from, e.g. `"ai"` or `"community"`.

## Value

Character scalar Markdown issue body.
