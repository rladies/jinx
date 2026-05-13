# Crop and resize a directory profile image

Uses `magick` to crop to a square and resize for web display.

## Usage

``` r
directory_crop_image(
  path,
  width = 400,
  height = 400,
  gravity = "Center",
  output = path
)
```

## Arguments

- path:

  Path to the image file.

- width:

  Target width in pixels. Defaults to 400.

- height:

  Target height in pixels. Defaults to 400.

- gravity:

  Crop gravity. Defaults to `"Center"`.

- output:

  Output path. Defaults to overwriting the input.

## Value

Output path (invisibly).
