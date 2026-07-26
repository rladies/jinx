# Format the weekly question-gap digest as Slack mrkdwn

Distinct from
[`question_log_format()`](https://rladies.github.io/jinx/reference/question_log_format.md),
which renders a GitHub-comment markdown report for `/jinx questions` -
this builds the Slack message text posted by
[`question_digest_post()`](https://rladies.github.io/jinx/reference/question_digest_post.md).
R port of `format_digest()` from the deleted
`worker/src/question-digest.js`.

## Usage

``` r
question_digest_format(days, total, gaps, drafts, downvoted, coding_count)
```

## Arguments

- days:

  Number of days the report covers.

- total:

  Total questions logged in the period.

- gaps:

  Data frame from
  [`question_content_gaps()`](https://rladies.github.io/jinx/reference/question_content_gaps.md).

- drafts:

  Data frame: the top-drafted subset of `gaps`, plus a `draft` character
  column (`NA` where drafting failed).

- downvoted:

  Data frame from
  [`question_downvoted_rank()`](https://rladies.github.io/jinx/reference/question_downvoted_rank.md).

- coding_count:

  Integer from
  [`question_coding_declined_count()`](https://rladies.github.io/jinx/reference/question_coding_declined_count.md).

## Value

Character scalar Slack mrkdwn message.
