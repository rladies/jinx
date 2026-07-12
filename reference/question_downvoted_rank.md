# Rank questions where downvotes exceed upvotes

R port of `question_downvoted_rank()` in `worker/src/question-log.js`.

## Usage

``` r
question_downvoted_rank(rows, limit = 10)
```

## Arguments

- rows:

  Data frame from
  [`question_log_query()`](https://rladies.github.io/jinx/reference/question_log_query.md).

- limit:

  Maximum number of rows to return.

## Value

Subset of `rows` where `down > up`, ordered by `down - up` descending.
