# The display name for a chapter's GitHub team

GitHub derives a team's slug from its name and gives no way to set the
slug directly, so the name has to be chosen such that it slugifies back
to the chapter's urlname. That rules out "Portland, Oregon, USA" as a
name - it would produce `portland-oregon-usa` rather than `pdx`.

## Usage

``` r
chapter_team_name(slug, acronyms = chapter_team_acronyms())
```

## Arguments

- slug:

  Team slug, from
  [`chapter_team_slug()`](https://rladies.github.io/jinx/reference/chapter_team_slug.md).

- acronyms:

  Slugs to render upper case rather than title case.

## Value

The display name.

## Details

The readable description of the chapter goes in the team's description
instead, which is free text and does not affect the slug.
