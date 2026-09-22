# Summarise an onboarding checklist as markdown

Reports progress per section, names the next unchecked item and who owns
it, and says plainly when everything is done.

## Usage

``` r
chapter_onboard_summary(state, title = "Chapter onboarding")
```

## Arguments

- state:

  Data frame from
  [`chapter_onboard_state()`](https://rladies.github.io/jinx/reference/chapter_onboard_state.md).

- title:

  Chapter title to put in the heading.

## Value

Markdown body as a single string.
