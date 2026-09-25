describe("chapter_group_row", {
  it("prefers urlname over the social media field", {
    row <- chapter_group_row(list(
      file = "x.json",
      city = "Oslo",
      country = "Norway",
      status = "active",
      urlname = "rladies-oslo",
      social_media = list(meetup = "rladies-oslo")
    ))
    expect_identical(row$urlname, "rladies-oslo")
  })

  it("falls back to social_media.meetup when urlname is missing", {
    row <- chapter_group_row(list(
      file = "croatia-zagreb.json",
      city = "Zagreb",
      country = "Croatia",
      status = "active",
      social_media = list(meetup = "rladies-zagreb")
    ))
    expect_identical(row$urlname, "rladies-zagreb")
  })

  it("warns when the two fields disagree, and uses urlname", {
    expect_message(
      row <- chapter_group_row(list(
        file = "morocco-rabat.json",
        city = "Rabat",
        country = "Morocco",
        status = "active",
        urlname = "rladies-rabat-ma",
        social_media = list(meetup = "rladies-rabat")
      )),
      "disagree"
    )
    expect_identical(row$urlname, "rladies-rabat-ma")
  })

  it("returns NULL for a chapter with no group at all", {
    expect_null(chapter_group_row(list(
      file = "x.json",
      city = "Nowhere",
      country = "X",
      status = "prospective",
      social_media = list()
    )))
  })
})

describe("chapter_meetup_groups", {
  entries <- list(
    list(
      file = "a.json",
      city = "Oslo",
      country = "Norway",
      status = "active",
      urlname = "rladies-oslo",
      social_media = list(meetup = "rladies-oslo")
    ),
    list(
      file = "b.json",
      city = "Gone",
      country = "X",
      status = "retired on 01-04-2020",
      urlname = "rladies-gone",
      social_media = list(meetup = "rladies-gone")
    ),
    list(
      file = "c.json",
      city = "Soon",
      country = "Y",
      status = "prospective",
      urlname = "rladies-soon",
      social_media = list(meetup = "rladies-soon")
    ),
    list(
      file = "d.json",
      city = "NoGroup",
      country = "Z",
      status = "active",
      social_media = list()
    )
  )

  mock_fetch <- function() {
    local_mocked_bindings(
      chapter_index_fetch = function(...) paste0(letters[1:4], ".json"),
      chapter_entry_fetch = function(file, ...) {
        entries[[match(file, paste0(letters[1:4], ".json"))]]
      },
      .env = parent.frame()
    )
  }

  it("includes active and prospective chapters by default", {
    mock_fetch()
    expect_message(groups <- chapter_meetup_groups())
    expect_setequal(groups$urlname, c("rladies-oslo", "rladies-soon"))
  })

  it("excludes retired chapters, which have no upcoming events", {
    mock_fetch()
    expect_message(groups <- chapter_meetup_groups())
    expect_false("rladies-gone" %in% groups$urlname)
  })

  it("excludes chapters with no Meetup group", {
    mock_fetch()
    expect_message(groups <- chapter_meetup_groups())
    expect_false("NoGroup" %in% groups$city)
  })

  it("honours an explicit status filter", {
    mock_fetch()
    expect_message(groups <- chapter_meetup_groups(statuses = "prospective"))
    expect_identical(groups$urlname, "rladies-soon")
  })

  it("survives entries that could not be read", {
    local_mocked_bindings(
      chapter_index_fetch = function(...) c("a.json", "bad.json"),
      chapter_entry_fetch = function(file, ...) {
        if (file == "bad.json") NULL else entries[[1]]
      }
    )
    expect_message(groups <- chapter_meetup_groups())
    expect_identical(groups$urlname, "rladies-oslo")
  })
})

describe("event_sync_chapters chapter source", {
  it("reads the chapter list from the website data", {
    asked <- NULL
    local_mocked_bindings(
      chapter_meetup_groups = function(...) {
        data.frame(urlname = c("rladies-oslo", "rladies-bergen"))
      },
      event_list_chapter = function(ch, ...) {
        asked <<- c(asked, ch)
        event_empty_df()
      }
    )
    expect_message(event_sync_chapters(dry_run = TRUE))
    expect_identical(asked, c("rladies-oslo", "rladies-bergen"))
  })

  it("says so when no chapter has a group", {
    local_mocked_bindings(
      chapter_meetup_groups = function(...) data.frame(urlname = character(0))
    )
    expect_message(
      result <- event_sync_chapters(dry_run = TRUE),
      "No chapters with a Meetup group"
    )
    expect_identical(nrow(result), 0L)
  })

  it("lets an explicit chapter list bypass the lookup", {
    called <- FALSE
    local_mocked_bindings(
      chapter_meetup_groups = function(...) {
        called <<- TRUE
        data.frame(urlname = character(0))
      },
      event_list_chapter = function(ch, ...) event_empty_df()
    )
    expect_message(event_sync_chapters(
      dry_run = TRUE,
      chapters = "rladies-oslo"
    ))
    expect_false(called)
  })
})
