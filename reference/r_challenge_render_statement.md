# Render a challenge statement as a reprex

Runs the statement (task comment + setup + expected output as literals)
through the reprex runner, producing the rendered block shown to
solvers. Because it runs the statement on its own, a statement that
leaks the answer by calling the not-yet-written function errors out and
is rejected.

## Usage

``` r
r_challenge_render_statement(statement, runner = r_challenge_reprex_runner)
```

## Arguments

- statement:

  Character scalar of R source stating the challenge.

- runner:

  Function taking code lines and returning rendered reprex output.
  Defaults to the isolated reprex runner.

## Value

List with `ok` (logical) and `rendered` (character vector).
