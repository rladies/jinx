# The GitHub team slug for a chapter

The Meetup urlname, minus the `rladies-` prefix. This is the convention
108 of the 122 existing chapter teams already follow, and it is the only
chapter field that is unique: seven city names are shared by more than
one chapter, and it is the urlname that separates them - `london` from
`ldnont`, `pdx` from `portland-maine`.

## Usage

``` r
chapter_team_slug(urlname, overrides = character(0))
```

## Arguments

- urlname:

  Meetup urlname, with or without the `rladies-` prefix.

- overrides:

  Named character vector mapping a urlname to a slug, for chapters whose
  urlname makes a poor team name. Warsaw's is
  `Spotkania-Entuzjastow-R-Warsaw-R-Users-Group-Meetup`.

## Value

The team slug, or `NA_character_` when there is no urlname.
