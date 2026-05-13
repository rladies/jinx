# Execute a parsed jinx command

Returns the response message as a character string. The caller is
responsible for routing the message to the right destination (GitHub
issue comment, Slack, R console, etc.).

## Usage

``` r
cmd_execute(command)
```

## Arguments

- command:

  Parsed command list from
  [`cmd_parse()`](https://rladies.github.io/jinx/reference/cmd_parse.md).

## Value

Character string with the response message.
