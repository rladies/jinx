# List speaker recommendations for a conference

List speaker recommendations for a conference

## Usage

``` r
list_speaker_recommendations(conference, org = "rladies", repo = "global-team")
```

## Arguments

- conference:

  Conference name.

- org:

  GitHub organization.

- repo:

  Repository where CFP issues are tracked.

## Value

Data frame with columns: speaker, expertise, recommended_by.
