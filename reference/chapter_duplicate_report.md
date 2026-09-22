# Render a duplicate check as an onboarding issue comment

Turns the output of
[`chapter_duplicate_check()`](https://rladies.github.io/jinx/reference/chapter_duplicate_check.md)
into the markdown the onboarding team reads first: whether the city
already has a chapter, which nearby chapters should be cc'd, and which
names are close enough to be worth a second look.

## Usage

``` r
chapter_duplicate_report(matches, city, country, radius_km = 100)
```

## Arguments

- matches:

  Data frame from
  [`chapter_duplicate_check()`](https://rladies.github.io/jinx/reference/chapter_duplicate_check.md).

- city:

  Requested chapter city.

- country:

  Requested chapter country.

- radius_km:

  Radius used for the proximity search.

## Value

Markdown body as a single string.
