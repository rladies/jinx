write_chapter <- function(dir, filename, ...) {
  path <- file.path(dir, filename)
  jsonlite::write_json(list(...), path, auto_unbox = TRUE, pretty = TRUE)
  path
}

valid_chapter <- function(dir, filename = "norway-oslo.json", ...) {
  defaults <- list(
    urlname = "rladies-oslo",
    status = "active",
    country = "Norway",
    city = "Oslo",
    social_media = list(meetup = "rladies-oslo"),
    organizers = list(current = list("Athanasia Monika Mowinckel"))
  )
  overrides <- list(...)
  fields <- utils::modifyList(defaults, overrides)
  do.call(write_chapter, c(list(dir, filename), fields))
}

describe("chapter_validate_files()", {
  it("returns no issues for a well-formed chapter", {
    dir <- withr::local_tempdir()
    path <- valid_chapter(dir)
    expect_equal(nrow(chapter_validate_files(path)), 0)
  })

  it("reports a schema violation when a required field is missing", {
    dir <- withr::local_tempdir()
    path <- write_chapter(
      dir,
      "norway-oslo.json",
      status = "active",
      country = "Norway"
    )
    issues <- chapter_validate_files(path)
    expect_true("schema" %in% issues$check)
    expect_equal(issues$level[issues$check == "schema"], "error")
  })

  it("flags escaped byte placeholders left by earlier tooling", {
    dir <- withr::local_tempdir()
    path <- valid_chapter(dir, city = "Bogot<e1>")
    issues <- chapter_validate_files(path)
    encoding <- issues[issues$check == "encoding", ]
    expect_equal(nrow(encoding), 1)
    expect_equal(encoding$level, "error")
    expect_match(encoding$message, "<e1>", fixed = TRUE)
  })

  it("does not derive a filename from text it knows is corrupt", {
    dir <- withr::local_tempdir()
    path <- valid_chapter(dir, city = "Osl<f8>")
    checks <- chapter_validate_files(path)$check
    expect_true("encoding" %in% checks)
    expect_false("filename" %in% checks)
  })

  it("errors on a filename mismatch in an added file", {
    dir <- withr::local_tempdir()
    path <- valid_chapter(dir, filename = "oslo.json")
    issues <- chapter_validate_files(path, added = path)
    filename <- issues[issues$check == "filename", ]
    expect_equal(filename$level, "error")
    expect_match(filename$message, "norway-oslo.json", fixed = TRUE)
  })

  it("only warns on a filename mismatch in a modified file", {
    dir <- withr::local_tempdir()
    path <- valid_chapter(dir, filename = "oslo.json")
    issues <- chapter_validate_files(path)
    expect_equal(issues$level[issues$check == "filename"], "warning")
  })

  it("derives the expected filename from the region when present", {
    dir <- withr::local_tempdir()
    path <- valid_chapter(
      dir,
      filename = "brazil-sao-paulo-americana.json",
      country = "Brazil",
      city = "Americana",
      "state.region" = "São Paulo"
    )
    expect_false("filename" %in% chapter_validate_files(path)$check)
  })

  it("warns when urlname and social_media.meetup disagree", {
    dir <- withr::local_tempdir()
    path <- valid_chapter(
      dir,
      urlname = "rladies-oslo-no",
      social_media = list(meetup = "rladies-oslo")
    )
    urlname <- chapter_validate_files(path)
    urlname <- urlname[urlname$check == "urlname", ]
    expect_equal(urlname$level, "warning")
  })

  it("accepts a chapter with no urlname at all", {
    dir <- withr::local_tempdir()
    path <- valid_chapter(dir, urlname = NULL)
    expect_false("urlname" %in% chapter_validate_files(path)$check)
  })

  it("accepts the dated retirement status", {
    dir <- withr::local_tempdir()
    path <- valid_chapter(dir, status = "retired on 25-11-2024")
    expect_false("status" %in% chapter_validate_files(path)$check)
  })

  it("warns on an unrecognised status", {
    dir <- withr::local_tempdir()
    path <- valid_chapter(dir, status = "dormant")
    issues <- chapter_validate_files(path)
    expect_equal(issues$level[issues$check == "status"], "warning")
  })

  it("reports unparseable JSON without erroring", {
    dir <- withr::local_tempdir()
    path <- file.path(dir, "broken.json")
    writeLines("{not json", path)
    issues <- chapter_validate_files(path)
    expect_equal(issues$check, "parse")
  })

  it("checks every path it is given", {
    dir <- withr::local_tempdir()
    good <- valid_chapter(dir)
    bad <- valid_chapter(dir, filename = "oslo.json")
    issues <- chapter_validate_files(c(good, bad), added = bad)
    expect_equal(unique(issues$file), "oslo.json")
  })
})

describe("chapter_validate_report()", {
  it("confirms success when there are no issues", {
    report <- chapter_validate_report(chapter_validate_files(character()), 3)
    expect_match(report, "3 chapter files look good", fixed = TRUE)
  })

  it("uses the singular for a single file", {
    report <- chapter_validate_report(chapter_validate_files(character()), 1)
    expect_match(report, "1 chapter file look", fixed = TRUE)
  })

  it("separates errors from warnings", {
    dir <- withr::local_tempdir()
    path <- valid_chapter(dir, city = "Bogot<e1>", status = "dormant")
    report <- chapter_validate_report(chapter_validate_files(path), 1)
    expect_match(report, "Must fix", fixed = TRUE)
    expect_match(report, "Worth a look", fixed = TRUE)
  })

  it("omits the error section when only warnings were found", {
    dir <- withr::local_tempdir()
    path <- valid_chapter(dir, status = "dormant")
    report <- chapter_validate_report(chapter_validate_files(path), 1)
    expect_false(grepl("Must fix", report, fixed = TRUE))
    expect_match(report, "Worth a look", fixed = TRUE)
  })
})
