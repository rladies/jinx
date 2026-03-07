# Execute a parsed jinx command

Execute a parsed jinx command

## Usage

``` r
execute_command(command, context)
```

## Arguments

- command:

  Parsed command list from
  [`parse_command()`](https://rladies.github.io/jinx/reference/parse_command.md).

- context:

  Named list with `repo` (e.g. "rladies/jinx") and `issue` (integer
  issue number).
