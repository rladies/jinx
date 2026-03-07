#' Crop and resize a directory profile image
#'
#' Uses `magick` to crop to a square and resize for web display.
#'
#' @param path Path to the image file.
#' @param width Target width in pixels. Defaults to 400.
#' @param height Target height in pixels. Defaults to 400.
#' @param gravity Crop gravity. Defaults to `"Center"`.
#' @param output Output path. Defaults to overwriting the input.
#' @return Output path (invisibly).
#' @export
crop_directory_image <- function(
  path,
  width = 400,
  height = 400,
  gravity = "Center",
  output = path
) {
  img <- magick::image_read(path)
  info <- magick::image_info(img)

  geometry <- sprintf("%dx%d", width, height)
  img <- magick::image_resize(img, paste0(geometry, "^"))
  img <- magick::image_crop(img, geometry, gravity = gravity)

  magick::image_write(img, output)
  cli::cli_alert_success("Cropped {.path {basename(path)}} to {width}x{height}")
  invisible(output)
}

#' Optimize an image for web display
#'
#' Resizes to max width and compresses.
#'
#' @param path Path to the image file.
#' @param max_width Maximum width in pixels. Defaults to 800.
#' @param quality JPEG quality (1-100). Defaults to 85.
#' @param output Output path. Defaults to overwriting the input.
#' @return Output path (invisibly).
#' @export
optimize_image <- function(path, max_width = 800, quality = 85, output = path) {
  img <- magick::image_read(path)
  info <- magick::image_info(img)

  if (info$width > max_width) {
    img <- magick::image_resize(img, paste0(max_width, "x"))
  }

  magick::image_write(img, output, quality = quality)

  new_info <- magick::image_info(magick::image_read(output))
  cli::cli_alert_success(
    "Optimized {.path {basename(path)}}: {info$width}x{info$height} -> {new_info$width}x{new_info$height}"
  )
  invisible(output)
}
