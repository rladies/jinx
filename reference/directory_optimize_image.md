# Optimize an image for web display

Resizes to max width and compresses.

## Usage

``` r
directory_optimize_image(path, max_width = 800, quality = 85, output = path)
```

## Arguments

- path:

  Path to the image file.

- max_width:

  Maximum width in pixels. Defaults to 800.

- quality:

  JPEG quality (1-100). Defaults to 85.

- output:

  Output path. Defaults to overwriting the input.

## Value

Output path (invisibly).
