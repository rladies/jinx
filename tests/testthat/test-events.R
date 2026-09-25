describe("event_meetup_to_df", {
  it("converts a valid event node to a data frame row", {
    node <- list(
      title = "Intro to R",
      dateTime = "2024-03-15T18:00:00",
      eventUrl = "https://meetup.com/rladies-berlin/events/123",
      going = 25
    )
    result <- event_meetup_to_df(node, "rladies-berlin")
    expect_s3_class(result, "data.frame")
    expect_identical(nrow(result), 1L)
    expect_identical(result$title, "Intro to R")
    expect_identical(result$date, as.Date("2024-03-15"))
    expect_identical(result$rsvp_count, 25L)
    expect_identical(result$source, "meetup")
    expect_identical(result$chapter, "rladies-berlin")
  })

  it("returns NULL for NULL node", {
    expect_null(event_meetup_to_df(NULL, "rladies-berlin"))
  })

  it("returns NULL for node without title", {
    expect_null(event_meetup_to_df(list(dateTime = "2024-01-01"), "ch"))
  })

  it("handles missing optional fields", {
    node <- list(title = "Test Event", dateTime = "2024-06-01T10:00:00")
    result <- event_meetup_to_df(node, "rladies-oslo")
    expect_identical(result$rsvp_count, 0L)
    expect_true(is.na(result$url))
  })
})

describe("event_empty_df", {
  it("returns a data frame with 0 rows and correct columns", {
    result <- event_empty_df()
    expect_s3_class(result, "data.frame")
    expect_identical(nrow(result), 0L)
    expect_named(
      result,
      c("title", "date", "url", "rsvp_count", "source", "chapter")
    )
  })
})

describe("event_create_summary", {
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
    result <- event_create_summary(events, "weekly")
    expect_true(grepl("weekly", result, ignore.case = TRUE))
    expect_true(grepl("2 events", result, fixed = TRUE))
    expect_true(grepl("2 chapters", result, fixed = TRUE))
    expect_true(grepl("Intro to R", result, fixed = TRUE))
    expect_true(grepl("ggplot2 Workshop", result, fixed = TRUE))
  })

  it("handles empty events", {
    result <- event_create_summary(event_empty_df(), "monthly")
    expect_true(grepl("No events found", result, fixed = TRUE))
  })
})

describe("event command parsing", {
  it("parses /jinx events <chapter>", {
    cmd <- cmd_parse("/jinx events rladies-berlin")
    expect_identical(cmd$action, "events")
    expect_identical(cmd$chapter, "rladies-berlin")
  })

  it("parses /jinx events sync", {
    cmd <- cmd_parse("/jinx events sync")
    expect_identical(cmd$action, "events-sync")
  })

  it("returns error for bare events command", {
    cmd <- cmd_parse("/jinx events")
    expect_identical(cmd$action, "error")
  })
})

describe("event_meetup_list via meetupr", {
  meetup_response <- function(nodes) {
    list(
      data = list(
        groupByUrlname = list(
          pastEvents = list(edges = lapply(nodes, function(n) list(node = n)))
        )
      )
    )
  }

  node <- function(title, when) {
    list(title = title, dateTime = when, eventUrl = "https://m/e", going = 12)
  }

  it("asks meetupr for the group, passing the urlname as a variable", {
    seen <- NULL
    local_mocked_bindings(
      meetupr_query = function(graphql, ...) {
        seen <<- list(graphql = graphql, args = list(...))
        meetup_response(list())
      },
      .package = "meetupr"
    )
    event_meetup_list("rladies-oslo")
    expect_identical(seen$args$urlname, "rladies-oslo")
    expect_match(seen$graphql, "groupByUrlname", fixed = TRUE)
  })

  it("returns an empty frame when the group has no past events", {
    local_mocked_bindings(
      meetupr_query = function(...) meetup_response(list()),
      .package = "meetupr"
    )
    expect_identical(nrow(event_meetup_list("rladies-oslo")), 0L)
  })

  it("keeps events inside the requested window and drops older ones", {
    recent <- format(Sys.Date() - 10, "%Y-%m-%dT10:00:00")
    ancient <- format(Sys.Date() - 400, "%Y-%m-%dT10:00:00")
    local_mocked_bindings(
      meetupr_query = function(...) {
        meetup_response(list(node("Recent", recent), node("Ancient", ancient)))
      },
      .package = "meetupr"
    )
    events <- event_meetup_list("rladies-oslo", months = 3)
    expect_identical(events$title, "Recent")
  })

  it("survives a group that does not exist", {
    local_mocked_bindings(
      meetupr_query = function(...) list(data = list(groupByUrlname = NULL)),
      .package = "meetupr"
    )
    expect_identical(nrow(event_meetup_list("rladies-nowhere")), 0L)
  })
})
