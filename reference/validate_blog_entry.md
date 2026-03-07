# Validate blog entry JSON files against schema

Validate blog entry JSON files against schema

## Usage

``` r
validate_blog_entry(
  path,
  schema = system.file("schemas", "blog-entry.json", package = "jinx")
)
```

## Arguments

- path:

  Path to a directory containing blog JSON files, or a single JSON file
  path.

- schema:

  Path to JSON schema file. Uses the bundled schema by default.

## Value

A data frame with columns `file`, `valid`, and `errors`.
