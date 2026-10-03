# Fetch a canonical communications template from the guide

Organisational communications - what RLadies+ says to organisers and
chapters - are written and edited in the guide, under
`static/templates/`, and served as markdown from
`https://guide.rladies.org/templates/<name>.md`. jinx fetches them
instead of shipping copies, so a volunteer can fix the wording without
waiting for a package release, and the text an organiser reads in the
guide is the text jinx sends.

## Usage

``` r
guide_template(name, variables = list(), base_url = guide_base_url())
```

## Arguments

- name:

  Template name without extension, as it is filed in the guide (for
  example `"meetup-group-description"`).

- variables:

  Named list of `<<KEY>>` placeholder values. Keys are given without the
  angle brackets. Placeholders the guide leaves for a human to fill are
  passed through untouched.

- base_url:

  Guide base URL, for testing against a local build.

## Value

The template text, as a single string.

## Details

A failed fetch is an error. There is deliberately no vendored fallback,
because a second copy is the drift this replaces.

Use
[`guide_email_template()`](https://rladies.github.io/jinx/reference/guide_email_template.md)
for a template that is sent as email and so carries its own subject
line.

## Examples

``` r
if (FALSE) { # \dontrun{
guide_template("meetup-group-description")

guide_template(
  "chapter-onboarding-welcome",
  list(FIRST_NAME = "Ada", CITY = "Oslo")
)
} # }
```
