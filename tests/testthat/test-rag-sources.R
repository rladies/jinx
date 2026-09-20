library(httr2)

describe("load_rag_sources", {
  it("loads the shipped YAML config with at least one source", {
    sources <- load_rag_sources()
    expect_gte(length(sources), 1L)
    expect_true(all(vapply(sources, function(s) !is.null(s$type), logical(1))))
  })
})

describe("gather_rag_source", {
  it("dispatches by type with dash-to-underscore lookup", {
    local_mocked_responses(list(response(body = charToRaw("[]"))))
    chunks <- gather_rag_source(list(
      type = "events-json",
      url = "https://example.com/x",
      repo = "r"
    ))
    expect_type(chunks, "list")
  })

  it("aborts on unknown source type", {
    expect_error(
      gather_rag_source(list(type = "no-such-source")),
      "Unknown source type"
    )
  })
})

describe("format_event", {
  it("renders all available fields as labelled lines", {
    ev <- list(
      title = "Tidy stats",
      group_name = "RLadies Oslo",
      datetime = "2025-06-01T18:00:00Z",
      status = "active",
      venue_name = "Forskningsparken",
      venue_city = "Oslo",
      going = 42L,
      description = "<p>Bring laptops</p>"
    )
    out <- format_event(ev)
    expect_match(out, "Title: Tidy stats")
    expect_match(out, "Chapter: RLadies Oslo")
    expect_match(out, "Status: upcoming")
    expect_match(out, "Where: Forskningsparken, Oslo")
    expect_match(out, "Attendance: 42")
    expect_match(out, "Bring laptops")
    expect_false(grepl("<p>", out, fixed = TRUE))
  })

  it("maps past status to a 'past' label", {
    expect_match(format_event(list(status = "past")), "Status: past")
  })
})

describe("format_event_venue", {
  it("joins parts with commas", {
    expect_identical(
      format_event_venue(list(venue_name = "A", venue_city = "B")),
      "A, B"
    )
  })

  it("falls back to ev$location when venue parts are missing", {
    expect_identical(
      format_event_venue(list(location = "Online")),
      "Online"
    )
  })
})

describe("strip_html", {
  it("strips tags and collapses whitespace", {
    expect_identical(strip_html("<p>hi  there</p>"), "hi there")
  })
})

describe("format_event_digest_line", {
  it("renders a Slack link when the event has a link", {
    line <- format_event_digest_line(list(
      group_name = "R-Ladies Oslo",
      title = "Tidy stats",
      datetime = "2026-06-01T18:00:00Z",
      link = "https://meetup.com/oslo/1"
    ))
    expect_match(
      line,
      "<https://meetup.com/oslo/1|R-Ladies Oslo: Tidy stats>",
      fixed = TRUE
    )
  })

  it("falls back to a plain label when no link is present", {
    line <- format_event_digest_line(list(
      group_name = "R-Ladies Oslo",
      title = "Tidy stats",
      datetime = "2026-06-01T18:00:00Z"
    ))
    expect_false(grepl("<", line, fixed = TRUE))
    expect_match(line, "R-Ladies Oslo: Tidy stats", fixed = TRUE)
  })

  it("appends the venue in parentheses when present", {
    line <- format_event_digest_line(list(
      group_name = "G",
      title = "T",
      datetime = "2026-06-01T18:00:00Z",
      venue_name = "Forskningsparken",
      venue_city = "Oslo"
    ))
    expect_match(line, "(Forskningsparken, Oslo)", fixed = TRUE)
  })

  it("neutralises Slack link metacharacters in an untrusted title", {
    line <- format_event_digest_line(list(
      group_name = "R-Ladies C",
      title = "A > B | C",
      datetime = "2026-07-10T18:00:00Z",
      link = "https://meetup.com/c/1"
    ))
    expect_match(
      line,
      "<https://meetup.com/c/1|R-Ladies C: A B C>",
      fixed = TRUE
    )
  })
})

describe("slack_link_label", {
  it("strips <, >, and | and collapses whitespace", {
    expect_identical(slack_link_label("A > B | C"), "A B C")
    expect_identical(slack_link_label("<script>"), "script")
  })
})

describe("events_digest_chunk", {
  it("returns NULL when no events are upcoming", {
    events <- list(
      list(status = "past", title = "Old", group_name = "G"),
      list(status = "cancelled", title = "X", group_name = "G")
    )
    expect_null(events_digest_chunk(events, list(repo = "r")))
  })

  it("emits one events-digest chunk ordered soonest first", {
    events <- list(
      list(
        status = "active",
        title = "Later",
        group_name = "R-Ladies B",
        datetime = "2026-09-01T18:00:00Z",
        datetime_utc = "2026-09-01T18:00:00Z",
        link = "https://meetup.com/b"
      ),
      list(
        status = "active",
        title = "Sooner",
        group_name = "R-Ladies A",
        datetime = "2026-07-01T18:00:00Z",
        datetime_utc = "2026-07-01T18:00:00Z",
        link = "https://meetup.com/a"
      )
    )
    chunk <- events_digest_chunk(events, list(repo = "rladies/meetup_archive"))
    expect_identical(chunk$source_type, "events-digest")
    expect_identical(chunk$path, "digest/upcoming-events")
    expect_identical(chunk$title, "Upcoming RLadies+ events")
    expect_lt(
      regexpr("Sooner", chunk$text, fixed = TRUE),
      regexpr("Later", chunk$text, fixed = TRUE)
    )
    expect_match(
      chunk$text,
      "<https://meetup.com/a|R-Ladies A: Sooner>",
      fixed = TRUE
    )
    expect_identical(chunk$date, rag_parse_date("2026-07-01T18:00:00Z"))
  })

  it("sorts events with a missing date last, not first", {
    events <- list(
      list(
        status = "active",
        title = "Date MISSING",
        group_name = "R-Ladies B",
        link = "https://meetup.com/b"
      ),
      list(
        status = "active",
        title = "Real July event",
        group_name = "R-Ladies A",
        datetime = "2026-07-10T18:00:00Z",
        datetime_utc = "2026-07-10T18:00:00Z",
        link = "https://meetup.com/a"
      )
    )
    chunk <- events_digest_chunk(events, list(repo = "r"))
    expect_lt(
      regexpr("Real July event", chunk$text, fixed = TRUE),
      regexpr("Date MISSING", chunk$text, fixed = TRUE)
    )
    expect_identical(chunk$date, rag_parse_date("2026-07-10T18:00:00Z"))
  })

  it("caps at max_events and notes the overflow with the landing url", {
    events <- lapply(1:3, function(i) {
      list(
        status = "active",
        title = paste0("E", i),
        group_name = "G",
        datetime = sprintf("2026-0%d-01T00:00:00Z", i),
        datetime_utc = sprintf("2026-0%d-01T00:00:00Z", i),
        link = paste0("https://m/", i)
      )
    })
    chunk <- events_digest_chunk(
      events,
      list(repo = "r", digest_url = "https://rladies.org/events/"),
      max_events = 2L
    )
    expect_match(chunk$text, "...and 1 more upcoming events", fixed = TRUE)
    expect_match(chunk$text, "https://rladies.org/events/", fixed = TRUE)
  })

  it("uses the configured digest_url as the chunk url", {
    events <- list(list(
      status = "active",
      title = "E",
      group_name = "G",
      datetime = "2026-07-01T00:00:00Z",
      link = "https://m/1"
    ))
    chunk <- events_digest_chunk(
      events,
      list(repo = "r", digest_url = "https://example.org/ev/")
    )
    expect_identical(chunk$url, "https://example.org/ev/")
  })
})

describe("format_awesome_package", {
  it("returns NULL when name is missing", {
    expect_null(format_awesome_package(list(name = ""), list(repo = "r")))
  })

  it("returns NULL when url is missing", {
    expect_null(format_awesome_package(
      list(name = "foo"),
      list(repo = "r")
    ))
  })

  it("renders package fields and uses pkdown_url as canonical url", {
    pkg <- list(
      name = "foo",
      title = "Foo Tools",
      authors = list(list(name = "A"), list(name = "B")),
      repo_url = "https://github.com/x/foo",
      pkdown_url = "https://x.github.io/foo",
      last_updated = "2024-06-01",
      description = "does  foo  things"
    )
    chunk <- format_awesome_package(pkg, list(repo = "rladies/x"))
    expect_identical(chunk$url, "https://x.github.io/foo")
    expect_match(chunk$text, "Package: foo")
    expect_match(chunk$text, "Authors: A, B")
    expect_match(chunk$text, "does foo things")
    expect_identical(chunk$path, "package/foo")
  })
})

describe("format_awesome_content", {
  it("prepends https:// to bare URLs", {
    chunk <- format_awesome_content(
      list(url = "example.com/x", title = "T"),
      list(repo = "r")
    )
    expect_identical(chunk$url, "https://example.com/x")
  })

  it("uses slugified title for path", {
    chunk <- format_awesome_content(
      list(url = "https://x", title = "Hello, World!"),
      list(repo = "r")
    )
    expect_identical(chunk$path, "content/hello-world")
  })
})

describe("format_authors", {
  it("joins names with commas, dropping blanks", {
    out <- format_authors(list(
      list(name = "A"),
      list(name = ""),
      list(name = "B")
    ))
    expect_identical(out, "A, B")
  })

  it("returns empty string for non-list or empty input", {
    expect_identical(format_authors(NULL), "")
    expect_identical(format_authors(list()), "")
  })
})

describe("slugify_awesome", {
  it("lowercases, replaces non-alnum with hyphens, and trims", {
    expect_identical(slugify_awesome("Hello, World!"), "hello-world")
  })

  it("caps length at 80", {
    expect_lte(nchar(slugify_awesome(strrep("a", 200))), 80L)
  })
})

describe("format_youtube_video", {
  it("includes title, published, and trimmed description", {
    out <- format_youtube_video("T", "2025-01-01T00:00:00Z", "  desc  ")
    expect_match(out, "Title: T")
    expect_match(out, "Published: 2025-01-01T00:00:00Z")
    expect_match(out, "^Title.*\n.*\n\ndesc$")
  })

  it("omits published when blank", {
    expect_false(grepl("Published", format_youtube_video("T", "", "d")))
  })
})

describe("render_team_text", {
  it("renders core fields with sensible defaults", {
    txt <- render_team_text(list(name = "Ops", slug = "ops"))
    expect_match(txt, "Team name: Ops")
    expect_match(txt, "Description: \\(no description\\)")
  })

  it("includes parent and visibility when present", {
    txt <- render_team_text(list(
      name = "X",
      slug = "x",
      parent = list(name = "Parent"),
      privacy = "closed"
    ))
    expect_match(txt, "Parent team: Parent")
    expect_match(txt, "Visibility: closed")
  })
})

describe("render_repo_meta_text", {
  it("renders core fields with sensible defaults", {
    repo <- list(
      full_name = "rladies/foo",
      html_url = "https://github.com/rladies/foo"
    )
    txt <- render_repo_meta_text(repo)
    expect_match(txt, "Repository: rladies/foo")
    expect_match(txt, "Topics: \\(none\\)")
    expect_match(txt, "Visibility: public")
  })

  it("renders topics list and private visibility", {
    txt <- render_repo_meta_text(list(
      full_name = "rladies/foo",
      private = TRUE,
      topics = list("r", "shiny"),
      html_url = "u"
    ))
    expect_match(txt, "Topics: r, shiny")
    expect_match(txt, "Visibility: private")
  })
})

describe("hugo URL helpers", {
  it("is_english_url accepts the configured English root", {
    src <- list(
      language_roots = list(english = "en", others = list("es", "fr"))
    )
    expect_true(is_english_url("https://x/en/about/", src))
    expect_false(is_english_url("https://x/es/about/", src))
  })

  it("is_english_url accepts root paths when english is unset", {
    src <- list(language_roots = list(english = NULL, others = list("es")))
    expect_true(is_english_url("https://x/about/", src))
    expect_false(is_english_url("https://x/es/about/", src))
  })

  it("is_skipped_url matches the configured skip patterns", {
    patterns <- c("^/directory/[^/]+/?$")
    expect_true(is_skipped_url("https://x/directory/jane-doe", patterns))
    expect_false(is_skipped_url("https://x/directory/", patterns))
  })

  it("normalise_hugo_url drops trailing index.html", {
    expect_identical(
      normalise_hugo_url("https://x/foo/index.html"),
      "https://x/foo/"
    )
  })

  it("strip_suffix removes the suffix when present", {
    expect_identical(strip_suffix("Hello :: World", " :: World"), "Hello")
    expect_identical(strip_suffix("Hello", " :: World"), "Hello")
  })
})
