# Format a question-log report as markdown

Format a question-log report as markdown

## Usage

``` r
question_log_format(rows, gaps, downvoted, days)
```

## Arguments

- rows:

  Data frame from
  [`question_log_query()`](https://rladies.github.io/jinx/reference/question_log_query.md).

- gaps:

  Data frame from
  [`question_gaps_rank()`](https://rladies.github.io/jinx/reference/question_gaps_rank.md).

- downvoted:

  Data frame from
  [`question_downvoted_rank()`](https://rladies.github.io/jinx/reference/question_downvoted_rank.md).

- days:

  Number of days the report covers, for the header.

## Value

Character string with markdown-formatted report.
