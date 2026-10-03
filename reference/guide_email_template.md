# Fetch a canonical email template from the guide

The guide writes the templates that are sent as email with their subject
on a leading `SUBJECT:` line, followed by `BODY OF THE MESSAGE:`. This
splits the two apart so that callers send the guide's subject rather
than inventing one, and errors if the template carries no subject at
all.

## Usage

``` r
guide_email_template(name, variables = list(), base_url = guide_base_url())
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

A list with `name`, `subject` and `body`.

## See also

[`guide_template()`](https://rladies.github.io/jinx/reference/guide_template.md)
for a template with no subject line.

## Examples

``` r
if (FALSE) { # \dontrun{
notice <- guide_email_template("chapter-inactive-first-notice")
notice$subject
} # }
```
