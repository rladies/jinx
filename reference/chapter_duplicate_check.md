# Check whether a requested chapter already exists or has neighbours

Performs the first step of the chapter onboarding checklist: searches
the website's `data/chapters` entries for a chapter in the same city,
for chapters with a near-identical city name, and for chapters in the
same country within `radius_km` of the requested city.

## Usage

``` r
chapter_duplicate_check(
  city,
  country,
  region = NULL,
  radius_km = 100,
  org = "rladies",
  website_repo = "rladies.github.io"
)
```

## Arguments

- city:

  Requested chapter city.

- country:

  Requested chapter country.

- region:

  State/region/province, or `NULL`.

- radius_km:

  Radius in kilometres for the proximity search. Set to `NULL` to skip
  geocoding entirely.

- org:

  GitHub organization. Defaults to `"rladies"`.

- website_repo:

  Repository holding `data/chapters`.

## Value

A data frame with one row per match and columns `city`, `country`,
`status`, `email`, `meetup`, `match`, and `distance_km`. `match` is one
of `"exact"`, `"similar"`, or `"nearby"`.

## Details

Only chapters in the requested country, or whose filename contains the
requested city slug, are fetched in full, so the check costs one
directory listing plus a handful of file reads.
