library(httr2)

describe("extract_hugo_page", {
  it("returns empty title and description when both meta tags are absent", {
    html <- "<!doctype html><html><head></head><body><main>just body content here that is long enough</main></body></html>"
    page <- extract_hugo_page(
      html,
      "http://x/",
      list(title_suffix = "", language_roots = list())
    )
    expect_identical(page$title, "")
    expect_identical(page$description, "")
  })

  it("does not embed the literal string NA in markdown when title and description are missing", {
    html <- "<!doctype html><html><head></head><body><main>just body content</main></body></html>"
    page <- extract_hugo_page(
      html,
      "http://x/",
      list(title_suffix = "", language_roots = list())
    )
    expect_false(grepl("NA", page$markdown, fixed = TRUE))
  })

  it("captures title and description when both are present", {
    html <- "<!doctype html><html><head><title>Hello</title><meta name='description' content='Desc'></head><body><main>body text</main></body></html>"
    page <- extract_hugo_page(
      html,
      "http://x/",
      list(title_suffix = "", language_roots = list())
    )
    expect_identical(page$title, "Hello")
    expect_identical(page$description, "Desc")
    expect_match(page$markdown, "Hello")
    expect_match(page$markdown, "Desc")
  })

  it("falls back to <article> when <main> is missing", {
    html <- "<!doctype html><html><head><title>T</title></head><body><article>article body content</article></body></html>"
    page <- extract_hugo_page(
      html,
      "http://x/",
      list(title_suffix = "", language_roots = list())
    )
    expect_false(is.null(page))
    expect_match(page$markdown, "article body")
  })

  it("returns NULL when neither <main> nor <article> is present", {
    html <- "<!doctype html><html><body><div>nope</div></body></html>"
    page <- extract_hugo_page(
      html,
      "http://x/",
      list(title_suffix = "", language_roots = list())
    )
    expect_null(page)
  })
})

describe("chunk_to_vector", {
  it("builds a vector record with 32-char hex id, embedding values, and metadata", {
    chunk <- list(
      text = "hello",
      heading = "H",
      title = "T",
      repo = "r/x",
      path = "/p",
      url = "u",
      source_type = "hugo-site",
      date = 100L,
      lastmod = 200L,
      chunk_idx = 0L
    )
    embedding <- c(0.1, 0.2, 0.3)
    vec <- chunk_to_vector(chunk, embedding)
    expect_match(vec$id, "^[0-9a-f]{32}$")
    expect_identical(vec$values, embedding)
    expect_identical(vec$metadata$url, "u")
    expect_identical(vec$metadata$title, "T")
    expect_identical(vec$metadata$heading, "H")
    expect_identical(vec$metadata$repo, "r/x")
    expect_identical(vec$metadata$path, "/p")
    expect_identical(vec$metadata$text, "hello")
    expect_identical(vec$metadata$source_type, "hugo-site")
    expect_identical(vec$metadata$date, 100L)
    expect_identical(vec$metadata$lastmod, 200L)
  })

  it("falls back lastmod to date when lastmod is missing", {
    chunk <- list(
      text = "t",
      heading = "",
      title = "T",
      repo = "r",
      path = "/p",
      url = "u",
      source_type = "x",
      date = 500L,
      chunk_idx = 0L
    )
    vec <- chunk_to_vector(chunk, c(0.5))
    expect_identical(vec$metadata$lastmod, 500L)
  })

  it("falls back lastmod and date to 0L when both are missing", {
    chunk <- list(
      text = "t",
      heading = "",
      title = "T",
      repo = "r",
      path = "/p",
      url = "u",
      source_type = "x",
      chunk_idx = 0L
    )
    vec <- chunk_to_vector(chunk, c(0.5))
    expect_identical(vec$metadata$date, 0L)
    expect_identical(vec$metadata$lastmod, 0L)
  })
})

describe("event_to_chunk", {
  it("returns NULL for cancelled events", {
    ev <- list(
      status = "cancelled",
      title = "T",
      group_name = "G",
      datetime = "2026-01-01T00:00:00Z"
    )
    expect_null(event_to_chunk(
      ev,
      src = list(repo = "r"),
      cutoff = 0L,
      min_chars = 0L
    ))
  })

  it("returns NULL for past events older than cutoff", {
    ev <- list(
      status = "past",
      title = "T",
      group_name = "G",
      datetime_utc = "2020-01-01T00:00:00Z"
    )
    cutoff <- as.integer(as.POSIXct("2024-01-01T00:00:00Z", tz = "UTC"))
    expect_null(event_to_chunk(
      ev,
      src = list(repo = "r"),
      cutoff = cutoff,
      min_chars = 0L
    ))
  })

  it("returns NULL when formatted text is shorter than min_chars", {
    ev <- list(status = "active", title = "T", group_name = "G")
    expect_null(event_to_chunk(
      ev,
      src = list(repo = "r"),
      cutoff = 0L,
      min_chars = 10000L
    ))
  })

  it("returns a chunk record with path = event/{id} for a normal event", {
    ev <- list(
      id = "evt-42",
      status = "active",
      title = "Tidy stats",
      group_name = "RLadies Oslo",
      datetime = "2026-06-01T18:00:00Z",
      datetime_utc = "2026-06-01T18:00:00Z",
      link = "https://example.com/e/42",
      description = "Bring laptops"
    )
    chunk <- event_to_chunk(
      ev,
      src = list(repo = "rladies/events"),
      cutoff = 0L,
      min_chars = 0L
    )
    expect_identical(chunk$path, "event/evt-42")
    expect_identical(chunk$title, "Tidy stats")
    expect_identical(chunk$heading, "RLadies Oslo")
    expect_identical(chunk$repo, "rladies/events")
    expect_identical(chunk$url, "https://example.com/e/42")
    expect_match(chunk$text, "Title: Tidy stats")
  })
})

describe("video_to_chunk", {
  it("returns NULL for Private video", {
    item <- list(
      snippet = list(
        title = "Private video",
        resourceId = list(videoId = "abc")
      )
    )
    expect_null(video_to_chunk(
      item,
      src = list(repo = "r"),
      max_description_chars = 100L
    ))
  })

  it("returns NULL for Deleted video", {
    item <- list(
      snippet = list(
        title = "Deleted video",
        resourceId = list(videoId = "abc")
      )
    )
    expect_null(video_to_chunk(
      item,
      src = list(repo = "r"),
      max_description_chars = 100L
    ))
  })

  it("returns NULL when resourceId$videoId is missing", {
    item <- list(snippet = list(title = "Real title", resourceId = list()))
    expect_null(video_to_chunk(
      item,
      src = list(repo = "r"),
      max_description_chars = 100L
    ))
  })

  it("builds a watch URL with the video id in the v query parameter", {
    item <- list(
      snippet = list(
        title = "Intro to R",
        description = "A nice talk",
        publishedAt = "2025-02-01T00:00:00Z",
        resourceId = list(videoId = "dQw4w9WgXcQ")
      )
    )
    chunk <- video_to_chunk(
      item,
      src = list(repo = "rladies/youtube"),
      max_description_chars = 100L
    )
    expect_identical(
      chunk$url,
      "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
    )
    expect_identical(chunk$path, "video/dQw4w9WgXcQ")
    expect_identical(chunk$title, "Intro to R")
  })

  it("truncates description to max_description_chars", {
    long_desc <- strrep("x", 500L)
    item <- list(
      snippet = list(
        title = "Talk",
        description = long_desc,
        publishedAt = "2025-02-01T00:00:00Z",
        resourceId = list(videoId = "vid1")
      )
    )
    chunk <- video_to_chunk(
      item,
      src = list(repo = "r"),
      max_description_chars = 50L
    )
    expect_true(nchar(chunk$text) < nchar(long_desc))
    expect_false(grepl(strrep("x", 100L), chunk$text, fixed = TRUE))
  })
})

describe("team_to_chunk", {
  it("returns NULL when team$privacy is set and not 'closed'", {
    team <- list(
      name = "Public Team",
      slug = "pub",
      privacy = "secret"
    )
    expect_null(team_to_chunk(team, src = list(org = "rladies")))
  })

  it("returns a chunk containing 'Team name: X' for a closed team", {
    team <- list(
      name = "Council",
      slug = "council",
      privacy = "closed",
      html_url = "https://github.com/orgs/rladies/teams/council"
    )
    chunk <- team_to_chunk(team, src = list(org = "rladies"))
    expect_false(is.null(chunk))
    expect_match(chunk$text, "Team name: Council")
    expect_identical(chunk$url, "https://github.com/orgs/rladies/teams/council")
    expect_identical(chunk$title, "Team: Council")
    expect_identical(chunk$repo, "rladies/.teams")
  })

  it("falls back to a synthesised github.com URL when html_url is absent", {
    team <- list(
      name = "Ops",
      slug = "ops",
      privacy = "closed"
    )
    chunk <- team_to_chunk(team, src = list(org = "rladies"))
    expect_match(chunk$url, "^https://github.com/")
    expect_match(chunk$url, "rladies")
    expect_match(chunk$url, "ops")
  })
})

describe("repo_to_chunks", {
  it("returns one meta chunk when there is no README", {
    local_mocked_bindings(gh_fetch_readme = function(full_name, token) NULL)
    repo <- list(
      full_name = "rladies/foo",
      html_url = "https://github.com/rladies/foo",
      description = "a repo",
      private = FALSE
    )
    chunks <- repo_to_chunks(repo, token = "tok")
    expect_length(chunks, 1L)
    expect_identical(chunks[[1]]$path, "_meta")
    expect_identical(chunks[[1]]$repo, "rladies/foo")
  })

  it("returns meta chunk plus README chunks when README is present", {
    long_readme <- paste0(
      "# Heading\n",
      strrep("alpha beta gamma delta ", 100L),
      "\n\n## Section Two\n",
      strrep("more content here ", 100L)
    )
    local_mocked_bindings(
      gh_fetch_readme = function(full_name, token) long_readme
    )
    repo <- list(
      full_name = "rladies/foo",
      html_url = "https://github.com/rladies/foo",
      description = "a repo",
      private = FALSE
    )
    chunks <- repo_to_chunks(repo, token = "tok")
    expect_gt(length(chunks), 1L)
    expect_identical(chunks[[1]]$path, "_meta")
    readme_chunks <- chunks[-1]
    paths <- vapply(readme_chunks, function(c) c$path, character(1))
    expect_true(all(paths == "README.md"))
  })
})

describe("assign_chunk_idx", {
  it("assigns zero-based chunk_idx to each chunk in order", {
    chunks <- list(
      list(text = "a"),
      list(text = "b"),
      list(text = "c")
    )
    out <- assign_chunk_idx(chunks)
    expect_length(out, 3L)
    indices <- vapply(out, function(c) c$chunk_idx, integer(1))
    expect_identical(indices, 0:2)
  })

  it("returns an empty list when given an empty list", {
    expect_identical(assign_chunk_idx(list()), list())
  })
})

describe("gather_rag_source dispatch", {
  it("dispatches events-json to gather_events_json without error on empty array", {
    local_mocked_responses(list(response(body = charToRaw("[]"))))
    result <- gather_rag_source(list(
      type = "events-json",
      url = "https://example.com/events.json",
      repo = "rladies/events"
    ))
    expect_identical(result, list())
  })

  it("aborts on unknown source type with an informative message", {
    expect_error(
      gather_rag_source(list(type = "no-such-source")),
      "Unknown source type"
    )
  })
})
