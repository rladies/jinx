# Parse a jinx command from an issue comment

Parses commands like:

- `/jinx invite @username to website`

- `/jinx offboard @username from blog`

- `/jinx report weekly`

- `/jinx help`

## Usage

``` r
command_parse(body)

cmd_parse(body)
```

## Arguments

- body:

  Character string, the comment body.

## Value

A named list with `action` and action-specific fields, or `NULL` if the
comment is not a jinx command.
