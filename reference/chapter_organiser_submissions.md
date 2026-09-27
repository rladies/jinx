# Find organiser form submissions for a chapter

The form's `chapter` field is free text and inconsistently written -
"Cologne, Germany" beside "Wake Forest, North Carolina EE.UU" - so
matching is by city slug appearing anywhere in it, and the caller is
expected to show a human what was found rather than act on it.

## Usage

``` r
chapter_organiser_submissions(city, api_key = Sys.getenv("AIRTABLE_API_KEY"))
```

## Arguments

- city:

  Chapter city.

- api_key:

  Airtable API key.

## Value

A data frame with `record_id`, `name`, `chapter`, `status`, and `type`;
empty when nothing matches.
