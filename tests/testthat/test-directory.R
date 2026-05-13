describe("directory_validate_filename", {
  it("accepts valid filenames", {
    result <- directory_validate_filename("jane-doe.json")
    expect_true(result$valid)
    expect_length(result$issues, 0)
  })

  it("rejects uppercase", {
    result <- directory_validate_filename("Jane-Doe.json")
    expect_false(result$valid)
    expect_true(any(grepl("lowercase", result$issues, fixed = TRUE)))
  })

  it("rejects missing .json extension", {
    result <- directory_validate_filename("jane-doe.txt")
    expect_false(result$valid)
    expect_true(any(grepl("json", result$issues, fixed = TRUE)))
  })

  it("rejects hash characters", {
    result <- directory_validate_filename("jane#doe.json")
    expect_false(result$valid)
    expect_true(any(grepl("hash", result$issues, fixed = TRUE)))
  })

  it("rejects non-ASCII characters", {
    result <- directory_validate_filename("jané-doe.json")
    expect_false(result$valid)
    expect_true(any(grepl("ASCII", result$issues, fixed = TRUE)))
  })

  it("rejects leading/trailing hyphens", {
    result <- directory_validate_filename("-jane-doe.json")
    expect_false(result$valid)
  })

  it("allows numbers and dots", {
    result <- directory_validate_filename("jane.doe-2.json")
    expect_true(result$valid)
  })
})

describe("directory_crop_image", {
  it("crops an image to specified dimensions", {
    skip_if_not_installed("magick")
    tmp <- withr::local_tempfile(fileext = ".png")
    img <- magick::image_blank(800, 600, color = "purple")
    magick::image_write(img, tmp)

    directory_crop_image(tmp, width = 200, height = 200)
    result <- magick::image_info(magick::image_read(tmp))
    expect_equal(result$width, 200)
    expect_equal(result$height, 200)
  })

  it("writes to separate output path", {
    skip_if_not_installed("magick")
    tmp_in <- withr::local_tempfile(fileext = ".png")
    tmp_out <- withr::local_tempfile(fileext = ".png")
    img <- magick::image_blank(800, 600, color = "purple")
    magick::image_write(img, tmp_in)

    directory_crop_image(tmp_in, output = tmp_out)
    expect_true(file.exists(tmp_out))
  })
})

describe("directory_optimize_image", {
  it("resizes large images", {
    skip_if_not_installed("magick")
    tmp <- withr::local_tempfile(fileext = ".png")
    img <- magick::image_blank(2000, 1500, color = "purple")
    magick::image_write(img, tmp)

    directory_optimize_image(tmp, max_width = 800)
    result <- magick::image_info(magick::image_read(tmp))
    expect_lte(result$width, 800)
  })

  it("does not upscale small images", {
    skip_if_not_installed("magick")
    tmp <- withr::local_tempfile(fileext = ".png")
    img <- magick::image_blank(400, 300, color = "purple")
    magick::image_write(img, tmp)

    directory_optimize_image(tmp, max_width = 800)
    result <- magick::image_info(magick::image_read(tmp))
    expect_equal(result$width, 400)
  })
})
