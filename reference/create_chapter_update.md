# Create a chapter update issue

Opens a tracking issue for updating an existing chapter's
infrastructure.

## Usage

``` r
create_chapter_update(
  city,
  country,
  org = "rladies",
  onboarding_repo = "new-chapters-onboarding"
)
```

## Arguments

- city:

  Chapter city name.

- country:

  Chapter country.

- org:

  GitHub organization. Defaults to `"rladies"`.

- onboarding_repo:

  Repository for chapter onboarding issues.

## Value

Issue URL (invisibly).
