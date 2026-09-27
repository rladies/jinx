# Create a chapter's GitHub team

Creates the team nested under the `chapters` parent, named so that its
slug matches the chapter's Meetup urlname, with the chapter spelled out
in the description.

## Usage

``` r
chapter_team_create(
  urlname,
  city,
  country,
  region = NULL,
  org = "rladies",
  parent_team = "chapters",
  overrides = character(0)
)
```

## Arguments

- urlname:

  Meetup urlname for the chapter.

- city:

  Chapter city.

- country:

  Chapter country.

- region:

  State/region/province, or `NULL`.

- org:

  GitHub organization. Defaults to `"rladies"`.

- parent_team:

  Slug of the parent team.

- overrides:

  Passed to
  [`chapter_team_slug()`](https://rladies.github.io/jinx/reference/chapter_team_slug.md).

## Value

The created team's slug (invisibly).
