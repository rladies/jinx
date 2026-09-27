# Create a chapter's presentations repository

Opt-in: not every chapter wants one, and only 111 of the 122 existing
teams have a repository, so this is never called as part of onboarding
without someone asking for it.

## Usage

``` r
chapter_repo_create(team_slug, city, country, region = NULL, org = "rladies")
```

## Arguments

- team_slug:

  Team slug, from
  [`chapter_team_slug()`](https://rladies.github.io/jinx/reference/chapter_team_slug.md).

- city:

  Chapter city.

- country:

  Chapter country.

- region:

  State/region/province, or `NULL`.

- org:

  GitHub organization. Defaults to `"rladies"`.

## Value

The repository name (invisibly).

## Details

The repository is public and the chapter's team is given `admin`,
matching every existing chapter repository - organisers administer their
own.
