# Rank content-gap questions by normalized-duplicate count

R port of `question_gaps_rank()` in `worker/src/question-log.js`.
Near-identical questions (case/whitespace-insensitive) are folded
together so a popular unanswered question rises to the top.

## Usage

``` r
question_gaps_rank(rows, limit = 10)
```

## Arguments

- rows:

  Data frame from
  [`question_log_query()`](https://rladies.github.io/jinx/reference/question_log_query.md).

- limit:

  Maximum number of gaps to return.

## Value

Data frame with columns `question`, `outcome`, `count`, ordered by
`count` descending.
