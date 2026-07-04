# Build the `location` object, resolving the linked country label.

`directory_prefixed` would otherwise leave the raw `location_country`
link id under `country`, so it is dropped and replaced with the resolved
label.

## Usage

``` r
directory_location(fields, country_lookup)
```
