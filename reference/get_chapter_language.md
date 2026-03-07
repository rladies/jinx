# Get a chapter's preferred language

Looks up the chapter's language preference from its metadata. Falls back
to English if not set.

## Usage

``` r
get_chapter_language(chapter, org = "rladies")
```

## Arguments

- chapter:

  Chapter slug (e.g. "rladies-berlin").

- org:

  GitHub organization.

## Value

Language code string.
