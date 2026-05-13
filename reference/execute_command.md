# Execute a parsed jinx command

Returns the response message as a character string. The caller is
responsible for routing the message to the right destination (GitHub
issue comment, Slack, R console, etc.).

## Usage

``` r
command_execute(command)
cmd_execute(command)
```

## Arguments

- command:

  Parsed command list from
  [`command_parse()`](https://rladies.github.io/jinx/reference/parse_command.md).

## Value

Character string with the response message.
