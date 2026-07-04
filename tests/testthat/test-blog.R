describe("validate_blog_entry", {
  it("validates a correct blog entry", {
    tmp <- withr::local_tempdir()
    entry <- list(
      title = "My R-Ladies Talk",
      url = "https://example.com/blog",
      type = "blog",
      authors = list(list(name = "Jane Doe")),
      language = "en"
    )
    path <- file.path(tmp, "entry.json")
    jsonlite::write_json(entry, path, auto_unbox = TRUE)

    result <- validate_blog_entry(path)
    expect_true(result$valid[1])
  })

  it("rejects entry missing required fields", {
    tmp <- withr::local_tempdir()
    entry <- list(title = "Missing fields")
    path <- file.path(tmp, "bad.json")
    jsonlite::write_json(entry, path, auto_unbox = TRUE)

    result <- validate_blog_entry(path)
    expect_false(result$valid[1])
    expect_true(nzchar(result$errors[1]))
  })

  it("validates all json files in a directory", {
    tmp <- withr::local_tempdir()
    good <- list(
      title = "Good",
      url = "https://x.com",
      type = "blog",
      authors = list(list(name = "A")),
      language = "en"
    )
    bad <- list(title = "Bad")
    jsonlite::write_json(good, file.path(tmp, "good.json"), auto_unbox = TRUE)
    jsonlite::write_json(bad, file.path(tmp, "bad.json"), auto_unbox = TRUE)

    result <- validate_blog_entry(tmp)
    expect_identical(nrow(result), 2L)
    expect_true(any(result$valid))
    expect_false(all(result$valid))
  })

  it("handles invalid JSON gracefully", {
    tmp <- withr::local_tempdir()
    path <- file.path(tmp, "broken.json")
    writeLines("not json at all {{{", path)

    result <- validate_blog_entry(path)
    expect_false(result$valid[1])
  })
})

describe("blog_entry_filename", {
  it("slugifies the domain to {domain}.json", {
    expect_identical(
      blog_entry_filename("https://drmowinckels.io/blog/x"),
      "drmowinckels.io.json"
    )
    expect_identical(
      blog_entry_filename("http://Example.COM/"),
      "example.com.json"
    )
  })
})

describe("blog_build_entry", {
  it("assembles an entry from OpenGraph metadata", {
    html <- paste0(
      '<meta property="og:title" content="My Post">',
      '<meta property="og:description" content="Desc">',
      '<meta property="og:image" content="https://x/img.png">',
      '<meta name="author" content="Jane Doe">'
    )
    local_mocked_bindings(
      req_perform = function(req) "resp",
      resp_body_string = function(resp) html,
      .package = "httr2"
    )
    entry <- blog_build_entry("https://x.com")
    expect_identical(entry$title, "My Post")
    expect_identical(entry$type, "blog")
    expect_identical(entry$authors[[1]]$name, "Jane Doe")
  })

  it("prefers an explicit author over page metadata", {
    local_mocked_bindings(
      req_perform = function(req) "resp",
      resp_body_string = function(resp) "<title>Fallback</title>",
      .package = "httr2"
    )
    entry <- blog_build_entry("https://x.com", author_name = "Given Name")
    expect_identical(entry$authors[[1]]$name, "Given Name")
    expect_identical(entry$title, "Fallback")
  })
})

describe("blog_add_pr", {
  it("skips when an entry already exists", {
    local_mocked_bindings(
      gh = function(endpoint, ...) list(sha = "abc"),
      .package = "gh"
    )
    result <- blog_add_pr("https://drmowinckels.io")
    expect_identical(result$status, "exists")
    expect_identical(result$filename, "drmowinckels.io.json")
    expect_null(result$url)
  })

  it("opens a PR when the entry is new", {
    calls <- character()
    local_mocked_bindings(
      gh = function(endpoint, ...) {
        calls[[length(calls) + 1]] <<- endpoint
        if (grepl("^GET .*/contents/", endpoint)) {
          stop("404 not found")
        }
        list()
      },
      .package = "gh"
    )
    local_mocked_bindings(
      blog_build_entry = function(url, ...) {
        list(title = "T", url = url, type = "blog")
      },
      gh_branch_upsert = function(...) "sha",
      gh_open_or_update_pr = function(...) {
        "https://github.com/rladies/awesome-rladies-creations/pull/1"
      }
    )
    result <- blog_add_pr("https://newblog.com/post")
    expect_identical(result$status, "created")
    expect_match(result$url, "pull/1")
    expect_true(any(grepl("^PUT .*/contents/", calls)))
  })
})

describe("blog_links_report", {
  it("handles an empty or NULL report without erroring", {
    expect_match(blog_links_report(NULL), "No community blog entries")
    empty <- data.frame(
      file = character(0),
      url = character(0),
      rss_feed = character(0),
      url_status = integer(0),
      rss_status = integer(0)
    )
    expect_match(blog_links_report(empty), "No community blog entries")
  })

  it("celebrates when every link is healthy", {
    report <- data.frame(
      file = "a.json",
      url = "https://ok.com",
      rss_feed = NA_character_,
      url_status = 200L,
      rss_status = NA_integer_
    )
    expect_match(blog_links_report(report), "healthy")
  })

  it("lists broken url and rss entries", {
    report <- data.frame(
      file = c("a.json", "b.json"),
      url = c("https://ok.com", "https://dead.com"),
      rss_feed = c(NA_character_, NA_character_),
      url_status = c(200L, 404L),
      rss_status = c(NA_integer_, NA_integer_)
    )
    out <- blog_links_report(report)
    expect_match(out, "Broken blog links")
    expect_true(grepl("b.json", out, fixed = TRUE))
  })
})

describe("blog_check_links_repo", {
  it("flags entries with broken url or rss status", {
    local_mocked_bindings(
      gh = function(endpoint, ...) {
        list(
          list(
            type = "file",
            name = "a.json",
            download_url = "https://x/a.json"
          ),
          list(
            type = "file",
            name = "b.json",
            download_url = "https://x/b.json"
          ),
          list(type = "dir", name = "sub", download_url = NULL)
        )
      },
      .package = "gh"
    )
    local_mocked_bindings(
      fromJSON = function(txt, ...) {
        if (grepl("a.json", txt)) {
          list(url = "https://ok.com", rss_feed = "https://ok.com/feed")
        } else {
          list(url = "https://broken.com", rss_feed = NULL)
        }
      },
      .package = "jsonlite"
    )
    local_mocked_bindings(
      check_url_status = function(url) if (grepl("broken", url)) 404L else 200L
    )

    report <- blog_check_links_repo()
    expect_identical(nrow(report), 2L)
    expect_identical(report$url_status[report$file == "b.json"], 404L)
    expect_identical(report$url_status[report$file == "a.json"], 200L)
  })
})
