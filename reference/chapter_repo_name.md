# The presentations repository name for a chapter

`meetup-presentations_<team slug>`, matching the 127 repositories the
org already has. Hyphens are kept: `san-diego`, `sao-paulo` and
`kansas-city` all have them, and `sanfrancisco` is the outlier rather
than the rule.

## Usage

``` r
chapter_repo_name(team_slug)
```

## Arguments

- team_slug:

  Team slug, from
  [`chapter_team_slug()`](https://rladies.github.io/jinx/reference/chapter_team_slug.md).

## Value

The repository name.
