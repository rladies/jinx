# Derive a safe file extension from an attachment MIME type.

Reduces to the alphanumeric MIME subtype (e.g. `image/jpeg` -\> `jpeg`),
falling back to `png`. Guarantees the extension cannot carry path
separators or other unexpected characters into the written file path.

## Usage

``` r
directory_photo_ext(type)
```
