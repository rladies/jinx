# Verify a reference solution against its own tests

Assembles the solution plus a
[`base::stopifnot()`](https://rdrr.io/r/base/stopifnot.html) for each
test, runs it through `runner`, and treats an `#> Error` line (a failed
test or a broken solution) as verification failure.

## Usage

``` r
r_challenge_reprex_check(solution, tests, runner = r_challenge_reprex_runner)
```

## Arguments

- solution:

  Character scalar reference solution.

- tests:

  Character vector of R expressions expected to be `TRUE`.

- runner:

  Function taking a character vector of code lines and returning the
  rendered output. Defaults to the isolated reprex runner.

## Value

List with `ok` (logical) and `output` (character vector).
