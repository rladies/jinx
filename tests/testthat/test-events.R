describe("meetup_event_to_df", {
  it("converts a valid event node to a data frame row", {
    node <- list(
      title = "Intro to R",
      dateTime = "2024-03-15T18:00:00",
      eventUrl = "https://meetup.com/rladies-berlin/events/123",
      going = 25
    )
    result <- meetup_event_to_df(node, "rladies-berlin")
    expect_s3_class(result, "data.frame")
    expect_equal(nrow(result), 1)
    expect_equal(result$title, "Intro to R")
    expect_equal(result$date, as.Date("2024-03-15"))
    expect_equal(result$rsvp_count, 25L)
    expect_equal(result$source, "meetup")
    expect_equal(result$chapter, "rladies-berlin")
  })

  it("returns NULL for NULL node", {
    expect_null(meetup_event_to_df(NULL, "rladies-berlin"))
  })

  it("returns NULL for node without title", {
    expect_null(meetup_event_to_df(list(dateTime = "2024-01-01"), "ch"))
  })

  it("handles missing optional fields", {
    node <- list(title = "Test Event", dateTime = "2024-06-01T10:00:00")
    result <- meetup_event_to_df(node, "rladies-oslo")
    expect_equal(result$rsvp_count, 0L)
    expect_true(is.na(result$url))
  })
})

describe("empty_event_df", {
  it("returns a data frame with 0 rows and correct columns", {
    result <- empty_event_df()
    expect_s3_class(result, "data.frame")
    expect_equal(nrow(result), 0)
    expect_named(
      result,
      c("title", "date", "url", "rsvp_count", "source", "chapter")
    )
  })
})

describe("create_event_summary", {
  it("formats a weekly summary with events", {
    events <- data.frame(
      title = c("Intro to R", "ggplot2 Workshop"),
      date = as.Date(c("2024-03-15", "2024-03-20")),
      url = c("https://example.com/1", "https://example.com/2"),
      rsvp_count = c(25L, 40L),
      source = c("meetup", "meetup"),
      chapter = c("rladies-berlin", "rladies-london"),
      stringsAsFactors = FALSE
    )
    result <- create_event_summary(events, "weekly")
    expect_true(grepl("weekly", result, ignore.case = TRUE))
    expect_true(grepl("2 events", result))
    expect_true(grepl("2 chapters", result))
    expect_true(grepl("Intro to R", result))
    expect_true(grepl("ggplot2 Workshop", result))
  })

  it("handles empty events", {
    result <- create_event_summary(empty_event_df(), "monthly")
    expect_true(grepl("No events found", result))
  })
})

describe("event command parsing", {
  it("parses /jinx events <chapter>", {
    cmd <- parse_command("/jinx events rladies-berlin")
    expect_equal(cmd$action, "events")
    expect_equal(cmd$chapter, "rladies-berlin")
  })

  it("parses /jinx events sync", {
    cmd <- parse_command("/jinx events sync")
    expect_equal(cmd$action, "events-sync")
  })

  it("returns error for bare events command", {
    cmd <- parse_command("/jinx events")
    expect_equal(cmd$action, "error")
  })
})
