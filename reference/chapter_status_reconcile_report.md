# Render a status reconciliation as markdown

Render a status reconciliation as markdown

## Usage

``` r
chapter_status_reconcile_report(reconciled, months = 6)
```

## Arguments

- reconciled:

  Data frame from
  [`chapter_status_reconcile()`](https://rladies.github.io/jinx/reference/chapter_status_reconcile.md).

- months:

  Months used for the inactivity window, for the wording.

## Value

A markdown string.
