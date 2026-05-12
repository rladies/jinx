# Execute a parsed jinx command

Returns the response message as a character string. The caller is
responsible for routing the message to the right destination (GitHub
issue comment, Slack, R console, etc.).

## Usage

``` r
execute_command(command)
```

## Arguments

- command:

  Parsed command list from
  [`parse_command()`](https://rladies.github.io/jinx/reference/parse_command.md).

## Value

Character string with the response message.
