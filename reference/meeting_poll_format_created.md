# Format a created poll as a markdown announcement

Deliberately omits the edit token, which is a host secret.

## Usage

``` r
meeting_poll_format_created(created, title)
```

## Arguments

- created:

  A list returned by
  [`meeting_poll_create()`](https://rladies.github.io/jinx/reference/meeting_poll_create.md).

- title:

  The poll title.

## Value

Character string of markdown.
