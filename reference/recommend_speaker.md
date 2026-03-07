# Recommend a speaker for a conference

Adds a speaker recommendation as a comment on the CFP tracking issue.

## Usage

``` r
recommend_speaker(
  conference,
  speaker_name,
  speaker_github = NULL,
  expertise = character(0),
  org = "rladies",
  repo = "global-team"
)
```

## Arguments

- conference:

  Conference name (matched against open CFP issues).

- speaker_name:

  Speaker name or GitHub username.

- speaker_github:

  Optional GitHub username.

- expertise:

  Character vector of expertise areas.

- org:

  GitHub organization.

- repo:

  Repository where CFP issues are tracked.

## Value

Comment URL (invisibly).
