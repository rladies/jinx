describe("chapter_slug", {
  it("transliterates accented names to the website's ascii form", {
    expect_identical(chapter_slug("Córdoba"), "cordoba")
    expect_identical(chapter_slug("São Paulo"), "sao-paulo")
  })

  it("joins parts and trims stray hyphens", {
    expect_identical(chapter_slug("Brazil", "Sao Paulo"), "brazil-sao-paulo")
    expect_identical(chapter_slug("St. Louis"), "st-louis")
  })

  it("drops empty and missing parts", {
    expect_identical(
      chapter_slug("Chile", NULL, "Valparaíso"),
      "chile-valparaiso"
    )
    expect_identical(chapter_slug(NA_character_, ""), "")
  })
})

describe("chapter_filename", {
  it("uses country-city when there is no region", {
    expect_identical(
      chapter_filename("Zurich", "Switzerland"),
      "switzerland-zurich.json"
    )
  })

  it("inserts the region between country and city", {
    expect_identical(
      chapter_filename("La Plata", "Argentina", "Buenos Aires"),
      "argentina-buenos-aires-la-plata.json"
    )
  })
})

describe("chapter_candidate_files", {
  files <- c(
    "argentina-cordoba-cordoba.json",
    "brazil-sao-paulo-sao-paulo.json",
    "spain-cordoba.json",
    "switzerland-zurich.json"
  )

  it("keeps every chapter in the requested country", {
    expect_setequal(
      chapter_candidate_files(files, "rosario", "argentina"),
      "argentina-cordoba-cordoba.json"
    )
  })

  it("keeps same-city chapters in other countries", {
    expect_setequal(
      chapter_candidate_files(files, "cordoba", "mexico"),
      c("argentina-cordoba-cordoba.json", "spain-cordoba.json")
    )
  })

  it("does not match a city slug inside a longer word", {
    expect_length(chapter_candidate_files(files, "paul", "france"), 0)
  })
})

describe("chapter_match_kind", {
  it("calls the same city in the same country exact", {
    expect_identical(
      chapter_match_kind("cordoba", "argentina", "cordoba", "argentina"),
      "exact"
    )
  })

  it("calls the same city name elsewhere similar", {
    expect_identical(
      chapter_match_kind("cordoba", "spain", "cordoba", "argentina"),
      "similar"
    )
  })

  it("calls a near-identical name in the same country similar", {
    expect_identical(
      chapter_match_kind("rosario", "argentina", "rosari", "argentina"),
      "similar"
    )
  })

  it("leaves an unrelated chapter unclassified", {
    expect_true(is.na(
      chapter_match_kind("zurich", "switzerland", "cordoba", "argentina")
    ))
  })
})

describe("chapter_match_table", {
  entry <- list(
    file = "spain-cordoba.json",
    city = "Córdoba",
    country = "Spain",
    status = "active",
    social_media = list(
      email = "cordoba@rladies.org",
      meetup = "rladies-cordoba"
    )
  )

  it("returns the documented columns when there is nothing to match", {
    table <- chapter_match_table(list(), "cordoba", "spain")
    expect_identical(nrow(table), 0L)
    expect_true(all(c("city", "country", "match") %in% names(table)))
  })

  it("flattens an entry and classifies it", {
    table <- chapter_match_table(list(entry), "cordoba", "spain")
    expect_identical(table$match, "exact")
    expect_identical(table$email, "cordoba@rladies.org")
    expect_identical(table$city_slug, "cordoba")
  })

  it("fills missing social media with NA", {
    bare <- entry
    bare$social_media <- NULL
    table <- chapter_match_table(list(bare), "cordoba", "spain")
    expect_true(is.na(table$email))
    expect_true(is.na(table$meetup))
  })
})

describe("chapter_add_distances", {
  matches <- data.frame(
    file = "argentina-rosario.json",
    city = "Rosario",
    country = "Argentina",
    status = "active",
    email = NA_character_,
    meetup = NA_character_,
    city_slug = "rosario",
    country_slug = "argentina",
    distance_km = NA_real_,
    match = NA_character_,
    stringsAsFactors = FALSE
  )

  it("flags a chapter inside the radius as nearby", {
    local_mocked_bindings(
      geocode_city = function(city, country, region = NULL) {
        if (city == "Rosario") {
          c(lat = -32.95, lon = -60.64)
        } else {
          c(lat = -31.42, lon = -64.18)
        }
      }
    )
    result <- chapter_add_distances(
      matches,
      "Cordoba",
      "Argentina",
      NULL,
      500
    )
    expect_identical(result$match, "nearby")
    expect_true(result$distance_km > 300 && result$distance_km < 400)
  })

  it("leaves a chapter outside the radius unclassified", {
    local_mocked_bindings(
      geocode_city = function(city, country, region = NULL) {
        if (city == "Rosario") {
          c(lat = -32.95, lon = -60.64)
        } else {
          c(lat = -31.42, lon = -64.18)
        }
      }
    )
    result <- chapter_add_distances(
      matches,
      "Cordoba",
      "Argentina",
      NULL,
      100
    )
    expect_true(is.na(result$match))
  })

  it("skips the proximity pass when radius_km is NULL", {
    result <- chapter_add_distances(
      matches,
      "Cordoba",
      "Argentina",
      NULL,
      NULL
    )
    expect_true(is.na(result$distance_km))
  })

  it("warns and gives up when the requested city cannot be geocoded", {
    local_mocked_bindings(
      geocode_city = function(city, country, region = NULL) NULL
    )
    expect_message(
      result <- chapter_add_distances(
        matches,
        "Nowhere",
        "Argentina",
        NULL,
        100
      )
    )
    expect_true(is.na(result$match))
  })
})

describe("geocode_first_point", {
  it("returns NULL for an empty response", {
    expect_null(geocode_first_point(list()))
    expect_null(geocode_first_point(NULL))
  })

  it("returns NULL when the coordinates are not numeric", {
    expect_null(geocode_first_point(list(list(lat = "x", lon = "y"))))
  })

  it("parses the first hit", {
    point <- geocode_first_point(list(list(lat = "59.91", lon = "10.75")))
    expect_equal(point[["lat"]], 59.91)
    expect_equal(point[["lon"]], 10.75)
  })
})

describe("haversine_km", {
  it("measures a known distance", {
    oslo <- c(lat = 59.91, lon = 10.75)
    copenhagen <- c(lat = 55.68, lon = 12.57)
    expect_equal(haversine_km(oslo, copenhagen), 483, tolerance = 0.02)
  })

  it("is zero for a point against itself", {
    oslo <- c(lat = 59.91, lon = 10.75)
    expect_equal(haversine_km(oslo, oslo), 0)
  })
})

describe("chapter_duplicate_report", {
  matches <- data.frame(
    file = c("spain-cordoba.json", "argentina-rosario.json"),
    city = c("Córdoba", "Rosario"),
    country = c("Spain", "Argentina"),
    status = c("active", "active"),
    email = c("cordoba@rladies.org", NA_character_),
    meetup = c("rladies-cordoba", NA_character_),
    city_slug = c("cordoba", "rosario"),
    country_slug = c("spain", "argentina"),
    distance_km = c(NA_real_, 350),
    match = c("similar", "nearby"),
    stringsAsFactors = FALSE
  )

  it("says so when nothing matches", {
    body <- chapter_duplicate_report(
      chapter_match_empty(),
      "Cordoba",
      "Argentina"
    )
    expect_match(body, "No existing or nearby chapter found")
  })

  it("renders a section per match kind", {
    body <- chapter_duplicate_report(matches, "Cordoba", "Argentina")
    expect_match(body, "### Nearby chapters")
    expect_match(body, "### Similar chapter names")
    expect_match(body, "350 km away")
    expect_match(body, "cordoba@rladies.org", fixed = TRUE)
  })

  it("leads with the exact match when the city already has a chapter", {
    exact <- matches[1, ]
    exact$match <- "exact"
    body <- chapter_duplicate_report(exact, "Cordoba", "Spain")
    expect_match(body, "This city already has a chapter")
  })
})

describe("chapter_duplicate_comment", {
  it("warns and returns NULL when the check fails", {
    local_mocked_bindings(
      chapter_duplicate_check = function(...) stop("api down")
    )
    expect_message(result <- chapter_duplicate_comment(1, "Oslo", "Norway"))
    expect_null(result)
  })

  it("posts the rendered report on the issue", {
    posted <- NULL
    local_mocked_bindings(
      chapter_duplicate_check = function(...) chapter_match_empty()
    )
    local_mocked_bindings(
      gh = function(endpoint, ...) {
        posted <<- list(...)
        list()
      },
      .package = "gh"
    )
    body <- chapter_duplicate_comment(7, "Oslo", "Norway")
    expect_identical(posted$issue_number, 7)
    expect_match(body, "Duplicate check: Oslo, Norway")
  })
})
