library(httr2)

describe("rum_format_analytics", {
  it("renders overview, trend, and top tables", {
    analytics <- list(
      site_tag = "abc123",
      since = as.Date("2026-06-01"),
      until = as.Date("2026-07-01"),
      pageviews = data.frame(
        date = c("2026-06-01", "2026-06-02"),
        pageviews = c(10L, 20L),
        stringsAsFactors = FALSE
      ),
      top_pages = data.frame(
        requestPath = c("/", "/about"),
        count = c(15L, 5L),
        stringsAsFactors = FALSE
      ),
      top_sources = data.frame(
        refererHost = "google.com",
        count = 8L,
        stringsAsFactors = FALSE
      ),
      top_countries = data.frame(
        countryName = "Norway",
        count = 12L,
        stringsAsFactors = FALSE
      )
    )
    md <- rum_format_analytics(analytics)
    expect_match(md, "Total pageviews.*30", perl = TRUE)
    expect_match(md, "/about", fixed = TRUE)
    expect_match(md, "google.com", fixed = TRUE)
    expect_match(md, "Norway", fixed = TRUE)
  })

  it("reports no data available for empty top tables", {
    analytics <- list(
      site_tag = "abc123",
      since = as.Date("2026-06-01"),
      until = as.Date("2026-07-01"),
      pageviews = data.frame(date = character(), pageviews = integer()),
      top_pages = data.frame(requestPath = character(), count = integer()),
      top_sources = data.frame(refererHost = character(), count = integer()),
      top_countries = data.frame(countryName = character(), count = integer())
    )
    md <- rum_format_analytics(analytics)
    expect_match(md, "No timeseries data available")
    expect_match(md, "No page data available")
    expect_match(md, "No referral data available")
    expect_match(md, "No country data available")
  })
})

describe("rum_collect_analytics", {
  it("collects pageviews and top-dimension breakdowns", {
    pageviews_body <- list(
      data = list(
        viewer = list(
          accounts = list(list(
            rumPageloadEventsAdaptiveGroups = list(
              list(count = 10, dimensions = list(date = "2026-06-01")),
              list(count = 20, dimensions = list(date = "2026-06-02"))
            )
          ))
        )
      )
    )
    top_body <- function(dimension, value, count) {
      dims <- stats::setNames(list(value), dimension)
      list(
        data = list(
          viewer = list(
            accounts = list(list(
              rumPageloadEventsAdaptiveGroups = list(
                list(count = count, dimensions = dims)
              )
            ))
          )
        )
      )
    }
    local_mocked_responses(list(
      response_json(body = pageviews_body),
      response_json(body = top_body("requestPath", "/", 15)),
      response_json(body = top_body("refererHost", "google.com", 8)),
      response_json(body = top_body("countryName", "Norway", 12))
    ))

    expect_message(
      analytics <- rum_collect_analytics(
        account_id = "acc123",
        site_tag = "tag123",
        token = "tok",
        since = as.Date("2026-06-01"),
        until = as.Date("2026-07-01")
      ),
      "Collected RUM analytics"
    )

    expect_equal(sum(analytics$pageviews$pageviews), 30L)
    expect_equal(analytics$top_pages$requestPath, "/")
    expect_equal(analytics$top_sources$refererHost, "google.com")
    expect_equal(analytics$top_countries$countryName, "Norway")
  })
})

describe("parse_cf_analytics_command", {
  it("defaults to 30 days", {
    cmd <- cmd_parse("/jinx cf-analytics")
    expect_identical(cmd$action, "cf-analytics")
    expect_identical(cmd$days, 30L)
  })

  it("parses an explicit day count", {
    cmd <- cmd_parse("/jinx cf-analytics 7")
    expect_identical(cmd$action, "cf-analytics")
    expect_identical(cmd$days, 7L)
  })

  it("errors on a non-numeric day count", {
    cmd <- cmd_parse("/jinx cf-analytics soon")
    expect_identical(cmd$action, "error")
  })

  it("errors on a non-positive day count", {
    cmd <- cmd_parse("/jinx cf-analytics 0")
    expect_identical(cmd$action, "error")
  })

  it("normalizes the 'rum analytics' phrase", {
    cmd <- cmd_parse("/jinx rum analytics 7")
    expect_identical(cmd$action, "cf-analytics")
    expect_identical(cmd$days, 7L)
  })
})
