library(httr2)

describe("chapter_meetup_logo_path", {
  it("ships a square PNG of a sensible size", {
    path <- chapter_meetup_logo_path()
    expect_true(file.exists(path))
    info <- magick::image_info(magick::image_read(path))
    expect_identical(info$format, "PNG")
    expect_identical(info$width, info$height)
    expect_gte(info$width, 500)
  })
})

describe("chapter_meetup_group_id", {
  it("returns the id for a group that exists", {
    local_mocked_bindings(
      meetupr_query = function(...) {
        list(data = list(groupByUrlname = list(id = "123")))
      },
      .package = "meetupr"
    )
    expect_identical(chapter_meetup_group_id("rladies-oslo"), "123")
  })

  it("errors clearly when the group does not exist", {
    local_mocked_bindings(
      meetupr_query = function(...) list(data = list(groupByUrlname = NULL)),
      .package = "meetupr"
    )
    expect_error(chapter_meetup_group_id("rladies-nowhere"), "No Meetup group")
  })
})

describe("chapter_meetup_logo_upload", {
  it("refuses an image that is not there", {
    expect_error(
      chapter_meetup_logo_upload("rladies-oslo", image = "no-such-file.png"),
      "No image at"
    )
  })

  it("registers the photo as the group's main image", {
    sent <- NULL
    local_mocked_bindings(
      meetupr_query = function(graphql, ...) {
        args <- list(...)
        if (grepl("groupByUrlname", graphql)) {
          return(list(data = list(groupByUrlname = list(id = "123"))))
        }
        sent <<- args$input
        list(
          data = list(
            createGroupEventPhoto = list(
              uploadUrl = "https://upload.example/abc",
              imagePath = "p/1.png"
            )
          )
        )
      },
      .package = "meetupr"
    )
    local_mocked_responses(list(response(status_code = 200)))
    expect_message(path <- chapter_meetup_logo_upload("rladies-oslo"))
    expect_identical(sent$photoType, "GROUP_PHOTO")
    expect_true(sent$setAsMain)
    expect_identical(sent$groupId, "123")
    expect_identical(path, "p/1.png")
  })

  it("surfaces Meetup's refusal rather than carrying on", {
    local_mocked_bindings(
      meetupr_query = function(graphql, ...) {
        if (grepl("groupByUrlname", graphql)) {
          return(list(data = list(groupByUrlname = list(id = "123"))))
        }
        list(
          data = list(
            createGroupEventPhoto = list(
              error = list(message = "not an organiser")
            )
          )
        )
      },
      .package = "meetupr"
    )
    expect_error(chapter_meetup_logo_upload("rladies-oslo"), "not an organiser")
  })

  it("errors when no upload URL comes back", {
    local_mocked_bindings(
      meetupr_query = function(graphql, ...) {
        if (grepl("groupByUrlname", graphql)) {
          return(list(data = list(groupByUrlname = list(id = "123"))))
        }
        list(data = list(createGroupEventPhoto = list(imagePath = "p/1.png")))
      },
      .package = "meetupr"
    )
    expect_error(chapter_meetup_logo_upload("rladies-oslo"), "no upload URL")
  })
})

describe("/jinx chapter-meetup-logo parsing", {
  it("takes a urlname", {
    expect_identical(
      cmd_parse("/jinx chapter-meetup-logo rladies-oslo"),
      list(action = "chapter-meetup-logo", urlname = "rladies-oslo")
    )
  })

  it("accepts the spelled-out phrasing without colliding with chapter-meetup", {
    expect_identical(
      cmd_parse("/jinx chapter meetup logo rladies-oslo")$urlname,
      "rladies-oslo"
    )
    expect_identical(
      cmd_parse("/jinx chapter meetup 12")$action,
      "chapter-meetup"
    )
  })

  it("explains itself when given nothing", {
    expect_identical(cmd_parse("/jinx chapter-meetup-logo")$action, "error")
  })

  it("is gated, since it changes a live group", {
    expect_identical(
      jinx_commands()[["chapter-meetup-logo"]]$keyword,
      "jinx_gated"
    )
  })
})
