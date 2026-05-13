# Create a new chapter setup issue

Opens a tracking issue in the new-chapters-onboarding repo with the full
checklist for setting up a new RLadies+ chapter.

## Usage

``` r
chapter_create_setup(
  city,
  country,
  organizers,
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

- org:

  GitHub organization. Defaults to `"rladies"`.

- onboarding_repo:

  Repository for chapter onboarding issues.

## Value

Issue URL (invisibly).
