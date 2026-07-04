# Decode a GitHub contents object's base64 payload to a raw vector.

The contents API wraps base64 at column 60 with newlines, which are
stripped before decoding.

## Usage

``` r
directory_decode_raw(obj)
```
