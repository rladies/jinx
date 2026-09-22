# Create a new chapter setup issue

Opens a tracking issue in the new-chapters-onboarding repo with the full
checklist for setting up a new RLadies+ chapter.

## Usage

``` r
chapter_create_setup(
  city,
  country,
  organizers,
  region = NULL,
  org = "rladies",
  onboarding_repo = "new-chapters-onboarding"
)
```

## Arguments

- city:

  Chapter city name.

- country:

  Chapter country.

- organizers:

  Character vector of organizer names.

- region:

  State/region/province, or `NULL`. Used to narrow the duplicate check's
  proximity search.

- org:

  GitHub organization. Defaults to `"rladies"`.

- onboarding_repo:

  Repository for chapter onboarding issues.

## Value

Issue URL (invisibly).
