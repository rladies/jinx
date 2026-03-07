# Validate directory entry JSON files against schema

Validate directory entry JSON files against schema

## Usage

``` r
validate_directory_entries(
  path,
  schema = system.file("schemas", "directory-entry.json", package = "jinx")
)
```

## Arguments

- path:

  Path to a directory containing JSON entry files, or a single JSON file
  path.

- schema:

  Path to JSON schema file. Uses the bundled schema by default.

## Value

A data frame with columns `file`, `valid`, and `errors`.
