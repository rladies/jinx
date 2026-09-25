# Render the Meetup setup brief for a chapter

Everything the Meetup Pro team needs in one comment: the exact group
name and URL, the settings the organisational guidelines call for, and
the standard description ready to paste.

## Usage

``` r
chapter_meetup_brief(city, country, status = NULL)
```

## Arguments

- city:

  Chapter city.

- country:

  Chapter country.

- status:

  Result of
  [`meetup_urlname_status()`](https://rladies.github.io/jinx/reference/meetup_urlname_status.md),
  or `NULL` to skip the availability line.

## Value

Markdown body as a single string.
