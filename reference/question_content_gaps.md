# Rank content gaps for the weekly digest

Narrower sibling of
[`question_gaps_rank()`](https://rladies.github.io/jinx/reference/question_gaps_rank.md):
excludes `"coding_declined"` rows, since declining a coding question is
working as designed, not a corpus gap. R port of `content_gaps()` from
the deleted `worker/src/question-digest.js`.

## Usage

``` r
question_content_gaps(rows, min_count = 1, limit = 10)
```

## Arguments

- rows:

  Data frame from
  [`question_log_query()`](https://rladies.github.io/jinx/reference/question_log_query.md).

- min_count:

  Minimum occurrence count to keep a gap.

- limit:

  Maximum number of gaps to return.

## Value

Data frame with columns `question`, `outcome`, `count`.
