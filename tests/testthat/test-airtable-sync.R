describe("at_scalar / at_vector", {
  it("reads a scalar field, NA when absent", {
    fields <- list(first_name = "Jane", tags = list("a", "b"))
    expect_identical(at_scalar(fields, "first_name"), "Jane")
    expect_identical(at_scalar(fields, "missing"), NA_character_)
  })

  it("reads a multi-value field as a character vector", {
    fields <- list(contact = list("Twitter", "Email"), empty = list())
    expect_identical(at_vector(fields, "contact"), c("Twitter", "Email"))
    expect_identical(at_vector(fields, "empty"), character(0))
    expect_identical(at_vector(fields, "missing"), character(0))
  })
})

describe("punct_name", {
  it("appends a period to single-character words", {
    expect_identical(punct_name("A B Smith"), "A. B. Smith")
    expect_identical(punct_name("Jane Doe"), "Jane Doe")
  })

  it("returns empty string for empty input", {
    expect_identical(punct_name(character(0)), "")
  })
})

describe("social handle normalisers", {
  it("normalises twitter handles", {
    expect_identical(normalize_twitter("@MariaG"), "mariag")
    expect_identical(normalize_twitter("https://twitter.com/Foo"), "foo")
    expect_identical(normalize_twitter("https://x.com/Bar"), "bar")
    expect_identical(normalize_twitter(""), NA_character_)
  })

  it("normalises linkedin handles", {
    expect_identical(
      normalize_linkedin("https://www.linkedin.com/in/MariaG"),
      "mariag"
    )
    expect_identical(normalize_linkedin("mariag"), "mariag")
  })

  it("normalises mastodon URLs to handle form", {
    expect_identical(
      normalize_mastodon("https://mastodon.social/@user"),
      "@user@mastodon.social"
    )
    expect_identical(normalize_mastodon("not-a-url"), NA_character_)
  })
})

describe("directory_slug", {
  it("prefers directory_id over identifier", {
    fields <- list(directory_id = "jane-existing", identifier = "jane-new")
    expect_identical(directory_slug(fields), "jane-existing")
  })

  it("falls back to identifier and transliterates to ASCII", {
    fields <- list(identifier = "María-García")
    expect_identical(directory_slug(fields), "maria-garcia")
  })

  it("returns NA when neither is present", {
    expect_true(is.na(directory_slug(list())))
  })
})

describe("resolve_links / directory_lookup", {
  it("maps link ids to labels, dropping unknowns", {
    lookup <- directory_lookup(
      list(
        list(id = "rec1", fields = list(Language = "Spanish")),
        list(id = "rec2", fields = list(Language = "English"))
      ),
      "Language"
    )
    expect_identical(
      resolve_links(list("rec1", "rec2"), lookup),
      c("Spanish", "English")
    )
    expect_identical(resolve_links(list("recX"), lookup), character(0))
  })
})

describe("directory_r_groups", {
  it("pairs rgroup name/url fields into a named list", {
    fields <- list(
      rgroup_name_1 = "R-Ladies Madrid",
      rgroup_url_1 = "https://example.com",
      rgroup_name_2 = "R-Ladies Oslo",
      rgroup_url_2 = ""
    )
    result <- directory_r_groups(fields)
    expect_identical(result[["R-Ladies Madrid"]], "https://example.com")
    expect_identical(result[["R-Ladies Oslo"]], "")
  })
})

describe("directory_transform_record", {
  record <- list(
    id = "recABC",
    createdTime = "2026-01-15T10:00:00.000Z",
    fields = list(
      status = "Submitted",
      minority_gender = "yes",
      first_name = "Maria",
      last_name = "Garcia",
      identifier = "maria-garcia",
      pronouns = "she/her",
      speaker = "Yes",
      contact = list("Twitter"),
      languages = list("recL1", "recL2"),
      interests = list("recI1"),
      location_city = "Madrid",
      location_country = list("recC1"),
      some_twitter = "@MariaG",
      some_linkedin = "https://www.linkedin.com/in/mariag",
      work_title = "Data Scientist",
      work_organisation = "ACME",
      rgroup_name_1 = "R-Ladies Madrid",
      rgroup_url_1 = "https://example.com",
      email = "maria@example.com"
    )
  )
  lookups <- list(
    languages = c(recL1 = "Spanish", recL2 = "English"),
    countries = c(recC1 = "Spain"),
    interests = c(recI1 = "Machine Learning")
  )

  it("builds a full entry from a submission", {
    res <- directory_transform_record(record, lookups)
    expect_identical(res$slug, "maria-garcia")
    expect_identical(res$email, "maria@example.com")
    expect_false(res$delete)

    data <- res$data
    expect_identical(data$name, "Maria Garcia")
    expect_identical(data$identifier, "maria-garcia")
    expect_true(data$speaker)
    expect_identical(data$contact_method, list("Twitter"))
    expect_identical(data$languages, list("Spanish", "English"))
    expect_identical(data$interests, list("Machine Learning"))
    expect_identical(data$social_media$twitter, "mariag")
    expect_identical(data$social_media$linkedin, "mariag")
    expect_identical(data$work$title, "Data Scientist")
    expect_identical(data$location$city, "Madrid")
    expect_identical(data$location$country, "Spain")
    expect_identical(
      data$activities$r_groups[["R-Ladies Madrid"]],
      "https://example.com"
    )
    expect_identical(data$last_updated, "2026-01-15")
  })

  it("skips default rows and non-minority-gender records", {
    default_row <- record
    default_row$fields$status <- "DEFAULT ROW"
    expect_null(directory_transform_record(default_row, lookups))

    not_minority <- record
    not_minority$fields$minority_gender <- "no"
    expect_null(directory_transform_record(not_minority, lookups))
  })

  it("flags delete requests", {
    del <- record
    del$fields$request_type <- "Delete directory entry"
    expect_true(directory_transform_record(del, lookups)$delete)
  })
})

describe("directory_dedupe_slugs", {
  it("disambiguates colliding slugs", {
    entries <- list(
      list(slug = "jane", data = list(identifier = "jane")),
      list(slug = "jane", data = list(identifier = "jane"))
    )
    result <- directory_dedupe_slugs(entries)
    expect_identical(result[[1]]$slug, "jane")
    expect_identical(result[[2]]$slug, "jane-1")
    expect_identical(result[[2]]$data$identifier, "jane-1")
  })
})

describe("directory_merge", {
  it("overlays nested keys per sub-field and clears requested fields", {
    existing <- list(
      name = "Jane",
      bio = "old bio",
      social_media = list(twitter = "old", github = "janedoe")
    )
    data <- list(social_media = list(twitter = "new"))
    result <- directory_merge(existing, data, clear_fields = "bio")

    expect_null(result$bio)
    expect_identical(result$social_media$twitter, "new")
    expect_identical(result$social_media$github, "janedoe")
    expect_identical(result$name, "Jane")
  })
})

describe("directory_fingerprint", {
  it("is independent of key order and empty children", {
    a <- directory_fingerprint(list(b = 2, a = 1))
    b <- directory_fingerprint(list(a = 1, b = 2, empty = list()))
    expect_identical(a, b)
  })
})

describe("airtable_extract_photo", {
  it("extracts URL from photo field", {
    photo <- list(list(url = "https://example.com/photo.jpg"))
    expect_identical(
      airtable_extract_photo(photo),
      "https://example.com/photo.jpg"
    )
  })

  it("returns NULL for empty field or missing URL", {
    expect_null(airtable_extract_photo(NULL))
    expect_null(airtable_extract_photo(list()))
    expect_null(airtable_extract_photo(list(list(id = "att123"))))
  })
})

describe("directory_write_entries", {
  it("records a change for a new entry", {
    entries <- list(list(
      slug = "jane-doe",
      data = list(name = "Jane Doe", identifier = "jane-doe"),
      email = NULL,
      photo = NULL,
      clear_fields = character(0)
    ))
    local_mocked_bindings(
      gh = function(endpoint, ...) stop("not found"),
      .package = "gh"
    )
    result <- directory_write_entries(entries, "rladies", "directory")
    expect_length(result, 1)
    expect_identical(result[[1]]$path, "data/json/jane-doe.json")
    expect_identical(result[[1]]$kind, "entry")
    expect_true(grepl("Jane Doe", result[[1]]$text, fixed = TRUE))
  })

  it("skips an entry whose merged content is unchanged", {
    existing_text <- directory_to_json(list(name = "Jane Doe"))
    entries <- list(list(
      slug = "jane-doe",
      data = list(name = "Jane Doe"),
      email = NULL,
      photo = NULL,
      clear_fields = character(0)
    ))
    local_mocked_bindings(
      gh = function(endpoint, ...) {
        list(
          content = jsonlite::base64_enc(charToRaw(existing_text)),
          sha = "abc123"
        )
      },
      .package = "gh"
    )
    result <- directory_write_entries(entries, "rladies", "directory")
    expect_length(result, 0)
  })
})

describe("directory_create_pr", {
  it("returns NULL when nothing changed", {
    expect_null(directory_create_pr(list(), list(), "rladies", "directory"))
  })

  it("creates a branch, commits files, and opens a PR", {
    calls <- character(0)
    local_mocked_bindings(
      gh = function(endpoint, ...) {
        calls[[length(calls) + 1]] <<- endpoint
        if (grepl("git/ref/heads", endpoint)) {
          return(list(object = list(sha = "basesha")))
        }
        if (grepl("^GET /repos.*/pulls", endpoint)) {
          return(list())
        }
        if (grepl("^POST /repos.*/pulls", endpoint)) {
          return(list(html_url = "https://github.com/x/y/pull/42"))
        }
        list()
      },
      .package = "gh"
    )
    changes <- list(list(
      path = "data/json/a.json",
      text = "{}\n",
      sha = NULL,
      kind = "entry",
      slug = "a"
    ))
    url <- directory_create_pr(changes, list(), "rladies", "directory")
    expect_identical(url, "https://github.com/x/y/pull/42")
    expect_true(any(grepl("PUT /repos.*/contents/", calls)))
    expect_true(any(grepl("POST /repos.*/pulls", calls)))
  })
})
