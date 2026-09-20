# Format a challenge as a Slack message

Renders the difficulty badge, title, and the challenge's reprex
statement for posting to the community channel. The title flows through
`escape_markdown()` and the statement sits in a fenced code block (its
backticks stripped), so model- or user-generated text cannot inject
links or `<!channel>` mass-pings. The reference solution is never shown.

## Usage

``` r
r_challenge_format_slack(title, difficulty, statement)
```

## Arguments

- title:

  Challenge title.

- difficulty:

  Difficulty level (see
  [`r_challenge_difficulties()`](https://rladies.github.io/jinx/reference/r_challenge_difficulties.md)).

- statement:

  Rendered reprex statement (character vector or scalar).

## Value

Character scalar Slack mrkdwn message.
