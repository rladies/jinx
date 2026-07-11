describe("cmd_execute integration: producer to formatter", {
  it("contributors-list runs end-to-end with realistic producer output", {
    local_mocked_bindings(
      contributor_list = function(owner, repo, ...) {
        data.frame(
          login = c("alice", "bob"),
          contributions = c(10L, 5L),
          avatar_url = c("a.png", "b.png"),
          profile_url = c("a.url", "b.url"),
          stringsAsFactors = FALSE
        )
      }
    )
    result <- cmd_execute(list(action = "contributors-list", repo = "jinx"))
    expect_type(result, "character")
    expect_true(grepl("@alice", result, fixed = TRUE))
    expect_true(grepl("10", result, fixed = TRUE))
  })

  it("contributors-org runs end-to-end with contributor_list_org output", {
    local_mocked_bindings(
      contributor_list_org = function(...) {
        data.frame(
          login = c("alice", "bob"),
          repos = c(3L, 1L),
          contributions = c(42L, 7L),
          avatar_url = c("a.png", "b.png"),
          profile_url = c("a.url", "b.url"),
          stringsAsFactors = FALSE
        )
      }
    )
    result <- cmd_execute(list(action = "contributors-org"))
    expect_type(result, "character")
    expect_true(grepl("Top Contributors", result, fixed = TRUE))
    expect_true(grepl("@alice", result, fixed = TRUE))
    expect_true(grepl("42", result, fixed = TRUE))
    expect_false(grepl("NA", result, fixed = TRUE))
  })

  it("contributors-update reports the commit URL", {
    local_mocked_bindings(
      contributor_update = function(...) "https://github.com/x/y/commit/abc123"
    )
    result <- cmd_execute(list(action = "contributors-update", repo = "jinx"))
    expect_type(result, "character")
    expect_true(grepl("commit/abc123", result, fixed = TRUE))
  })

  it("contributors-update reports up-to-date when no PR is created", {
    local_mocked_bindings(
      contributor_update = function(...) NULL
    )
    result <- cmd_execute(list(action = "contributors-update", repo = "jinx"))
    expect_match(result, "up to date")
  })

  it("report runs report_generate then report_format_markdown", {
    local_mocked_bindings(
      report_generate = function(type, ...) {
        list(
          type = type,
          period = list(from = "2026-05-01", to = "2026-05-08"),
          generated_at = as.POSIXct("2026-05-08 12:00:00", tz = "UTC"),
          repos = list(
            list(
              repo = "jinx",
              commits = 3L,
              prs_opened = 1L,
              prs_merged = 1L,
              issues_opened = 2L,
              issues_closed = 1L
            )
          ),
          summary = list(
            total_commits = 3L,
            total_prs = 1L,
            total_prs_merged = 1L,
            total_issues = 2L,
            total_issues_closed = 1L,
            active_repos = 1L
          )
        )
      }
    )
    result <- cmd_execute(list(action = "report", type = "weekly"))
    expect_type(result, "character")
    expect_true(grepl("weekly", result, fixed = TRUE))
    expect_true(grepl("jinx", result, fixed = TRUE))
  })

  it("report-chapters runs chapter_check_health then chapter_format_report", {
    local_mocked_bindings(
      chapter_check_health = function(...) {
        data.frame(
          chapter = c("rladies-oslo", "rladies-berlin"),
          last_event = as.Date(c("2026-04-01", "2024-06-01")),
          months_inactive = c(1L, 23L),
          status = c("active", "inactive"),
          stringsAsFactors = FALSE
        )
      }
    )
    result <- cmd_execute(list(action = "report-chapters"))
    expect_type(result, "character")
    expect_true(grepl("Chapter Health Report", result, fixed = TRUE))
    expect_true(grepl("rladies-berlin", result, fixed = TRUE))
  })

  it("report-chapters reports empty data without erroring", {
    local_mocked_bindings(
      chapter_check_health = function(...) data.frame()
    )
    result <- cmd_execute(list(action = "report-chapters"))
    expect_match(result, "No chapter data")
  })

  it("chapter-health summarises inactive chapters", {
    local_mocked_bindings(
      chapter_check_health = function(...) {
        data.frame(
          chapter = c("rladies-oslo", "rladies-berlin"),
          last_event = as.Date(c("2026-04-01", "2024-06-01")),
          months_inactive = c(1L, 23L),
          status = c("active", "inactive"),
          stringsAsFactors = FALSE
        )
      }
    )
    result <- cmd_execute(list(action = "chapter-health"))
    expect_match(result, "1 inactive chapter")
    expect_true(grepl("rladies-berlin", result, fixed = TRUE))
    expect_false(grepl("rladies-oslo", result, fixed = TRUE))
  })

  it("chapter-health celebrates when all chapters are active", {
    local_mocked_bindings(
      chapter_check_health = function(...) {
        data.frame(
          chapter = "rladies-oslo",
          last_event = as.Date("2026-04-01"),
          months_inactive = 1L,
          status = "active",
          stringsAsFactors = FALSE
        )
      }
    )
    result <- cmd_execute(list(action = "chapter-health"))
    expect_match(result, "active")
  })

  it("chapter-health handles empty data", {
    local_mocked_bindings(
      chapter_check_health = function(...) data.frame()
    )
    result <- cmd_execute(list(action = "chapter-health"))
    expect_match(result, "No chapter data")
  })

  it("blog-add reports the PR url on success", {
    local_mocked_bindings(
      blog_add_pr = function(url, ...) {
        list(status = "created", filename = "x.json", url = "https://gh/pr/2")
      }
    )
    result <- cmd_execute(list(action = "blog-add", url = "https://x.com"))
    expect_match(result, "https://gh/pr/2")
  })

  it("blog-add reports when the entry already exists", {
    local_mocked_bindings(
      blog_add_pr = function(url, ...) {
        list(status = "exists", filename = "x.com.json", url = NULL)
      }
    )
    result <- cmd_execute(list(action = "blog-add", url = "https://x.com"))
    expect_match(result, "already listed")
  })

  it("blog-check-links summarises broken links", {
    local_mocked_bindings(
      blog_check_links_repo = function(...) {
        data.frame(
          file = c("a.json", "b.json"),
          url = c("https://ok.com", "https://broken.com"),
          rss_feed = c(NA_character_, NA_character_),
          url_status = c(200L, 404L),
          rss_status = c(NA_integer_, NA_integer_),
          stringsAsFactors = FALSE
        )
      }
    )
    result <- cmd_execute(list(action = "blog-check-links"))
    expect_match(result, "Broken blog links")
    expect_true(grepl("b.json", result, fixed = TRUE))
  })

  it("blog-check-links celebrates when all links are healthy", {
    local_mocked_bindings(
      blog_check_links_repo = function(...) {
        data.frame(
          file = "a.json",
          url = "https://ok.com",
          rss_feed = NA_character_,
          url_status = 200L,
          rss_status = NA_integer_,
          stringsAsFactors = FALSE
        )
      }
    )
    result <- cmd_execute(list(action = "blog-check-links"))
    expect_match(result, "healthy")
  })

  it("gha-dashboard runs gha_generate_dashboard then gha_format_dashboard", {
    local_mocked_bindings(
      gha_generate_dashboard = function(...) {
        list(
          list(
            repository = "rladies/jinx",
            workflows = list(
              list(
                name = "CI",
                url = "https://ci.url",
                run = "2026-05-13T00:00:00Z",
                state = "active",
                badge = "https://badge.url"
              )
            )
          )
        )
      }
    )
    result <- cmd_execute(list(action = "gha-dashboard"))
    expect_type(result, "character")
    expect_true(grepl("rladies/jinx", result, fixed = TRUE))
    expect_true(grepl("CI", result, fixed = TRUE))
  })

  it("workers-status runs cf_ops_workers_invocations then formats the table", {
    local_mocked_bindings(
      cf_ops_workers_invocations = function(...) {
        data.frame(
          date = "2026-07-01",
          script = "jinx",
          requests = 100L,
          errors = 0L,
          subrequests = 10L,
          cpu_p50_us = 12.5,
          cpu_p99_us = 80.0,
          stringsAsFactors = FALSE
        )
      }
    )
    result <- cmd_execute(list(action = "workers-status"))
    expect_type(result, "character")
    expect_true(grepl("2026-07-01", result, fixed = TRUE))
  })

  it("cache-purge purges and echoes back what was purged", {
    local_mocked_bindings(
      cf_ops_purge_cache = function(...) list(id = "purge1")
    )
    result <- cmd_execute(list(
      action = "cache-purge",
      prefixes = c("rladies.org/blog", "rladies.org/events")
    ))
    expect_type(result, "character")
    expect_true(grepl("rladies.org/blog", result, fixed = TRUE))
    expect_true(grepl("rladies.org/events", result, fixed = TRUE))
  })

  it("events runs event_list_chapter then event_create_summary", {
    local_mocked_bindings(
      event_list_chapter = function(chapter, ...) {
        data.frame(
          title = "Intro to R",
          date = as.Date("2026-05-01"),
          url = "https://meetup.com/x",
          rsvp_count = 25L,
          source = "meetup",
          chapter = chapter,
          stringsAsFactors = FALSE
        )
      }
    )
    result <- cmd_execute(list(action = "events", chapter = "rladies-oslo"))
    expect_type(result, "character")
    expect_true(grepl("Intro to R", result, fixed = TRUE))
    expect_true(grepl("rladies-oslo", result, fixed = TRUE))
  })

  it("events-sync runs sync then returns a summary", {
    local_mocked_bindings(
      event_sync_chapters = function(...) {
        data.frame(
          title = "Intro to R",
          date = as.Date("2026-05-01"),
          url = "https://meetup.com/x",
          rsvp_count = 25L,
          source = "meetup",
          chapter = "rladies-oslo",
          stringsAsFactors = FALSE
        )
      }
    )
    result <- cmd_execute(list(action = "events-sync"))
    expect_type(result, "character")
    expect_true(grepl("Intro to R", result, fixed = TRUE))
  })

  it("analytics returns markdown from analytics_generate_dashboard", {
    local_mocked_bindings(
      analytics_generate_dashboard = function(...) {
        list(trends = NULL, growth = NULL, markdown = "## Analytics\nbody")
      }
    )
    result <- cmd_execute(list(action = "analytics"))
    expect_match(result, "Analytics")
  })

  it("analytics falls back when no markdown is present", {
    local_mocked_bindings(
      analytics_generate_dashboard = function(...) {
        list(trends = NULL, growth = NULL, markdown = NULL)
      }
    )
    result <- cmd_execute(list(action = "analytics"))
    expect_match(result, "No analytics data")
  })

  it("website-analytics returns the markdown from the report", {
    local_mocked_bindings(
      website_generate_report = function(period, ...) {
        list(
          analytics = list(period = period),
          markdown = "## Website Analytics\nbody"
        )
      }
    )
    result <- cmd_execute(list(action = "website-analytics", period = "30d"))
    expect_type(result, "character")
    expect_match(result, "Website Analytics")
  })

  it("questions formats the gap/downvote report from the D1 log", {
    local_mocked_bindings(
      question_log_query = function(...) {
        data.frame(
          question = "how do I start a chapter?",
          outcome = "no_match",
          up = 0L,
          down = 0L,
          stringsAsFactors = FALSE
        )
      }
    )
    result <- cmd_execute(list(action = "questions", days = 14))
    expect_type(result, "character")
    expect_match(result, "Question Log")
  })

  it("cf-analytics returns the markdown from the RUM report", {
    local_mocked_bindings(
      rum_generate_report = function(since, until, ...) {
        list(
          analytics = list(since = since, until = until),
          markdown = "## Cloudflare Web Analytics\nbody"
        )
      }
    )
    result <- cmd_execute(list(action = "cf-analytics", days = 14))
    expect_type(result, "character")
    expect_match(result, "Cloudflare Web Analytics")
  })

  it("cfp-list formats the open CFP data frame", {
    local_mocked_bindings(
      cfp_list_open = function(...) {
        data.frame(
          conference = "useR! 2026",
          deadline = "2026-06-01",
          url = "https://example.com/cfp",
          number = 12L,
          status = "open",
          stringsAsFactors = FALSE
        )
      }
    )
    result <- cmd_execute(list(action = "cfp-list"))
    expect_type(result, "character")
    expect_true(grepl("useR! 2026", result, fixed = TRUE))
    expect_true(grepl("2026-06-01", result, fixed = TRUE))
  })

  it("cfp-list reports nothing open with empty data", {
    local_mocked_bindings(
      cfp_list_open = function(...) {
        data.frame(
          conference = character(0),
          deadline = character(0),
          url = character(0),
          number = integer(0),
          status = character(0),
          stringsAsFactors = FALSE
        )
      }
    )
    result <- cmd_execute(list(action = "cfp-list"))
    expect_match(result, "No open CFPs")
  })

  it("cfp-add reports the created issue URL", {
    local_mocked_bindings(
      cfp_create_issue = function(...) "https://github.com/x/y/issues/2"
    )
    result <- cmd_execute(list(
      action = "cfp-add",
      conference = "useR! 2026",
      deadline = "2026-06-01",
      url = "https://example.com/cfp"
    ))
    expect_match(result, "issues/2")
  })

  it("cfp-recommend reports the recommendation", {
    local_mocked_bindings(
      cfp_recommend_speaker = function(...) invisible(NULL)
    )
    result <- cmd_execute(list(
      action = "cfp-recommend",
      conference = "useR! 2026",
      speaker = "alice"
    ))
    expect_true(grepl("@alice", result, fixed = TRUE))
    expect_true(grepl("useR! 2026", result, fixed = TRUE))
  })

  it("translate-status formats i18n_check_coverage output", {
    local_mocked_bindings(
      i18n_check_coverage = function(...) {
        data.frame(
          language = c("es", "de"),
          total_templates = c(10L, 10L),
          translated = c(8L, 5L),
          coverage_pct = c(80, 50),
          stringsAsFactors = FALSE
        )
      }
    )
    result <- cmd_execute(list(action = "translate-status"))
    expect_type(result, "character")
    expect_true(grepl("**es**: 8/10 (80%)", result, fixed = TRUE))
    expect_true(grepl("**de**: 5/10 (50%)", result, fixed = TRUE))
  })

  it("translate-validate reports issues from i18n_validate_translations", {
    local_mocked_bindings(
      i18n_validate_translations = function(language, ...) {
        data.frame(
          template = c("welcome.md", "thanks.md"),
          language = c("es", "es"),
          status = c("mismatch", "ok"),
          missing_keys = c("NAME", ""),
          extra_keys = c("", ""),
          stringsAsFactors = FALSE
        )
      }
    )
    result <- cmd_execute(list(action = "translate-validate", language = "es"))
    expect_type(result, "character")
    expect_true(grepl("welcome.md (es): mismatch", result, fixed = TRUE))
    expect_false(grepl("thanks.md", result, fixed = TRUE))
  })

  it("translate-validate reports all-clear with no issues", {
    local_mocked_bindings(
      i18n_validate_translations = function(...) {
        data.frame(
          template = "welcome.md",
          language = "es",
          status = "ok",
          missing_keys = "",
          extra_keys = "",
          stringsAsFactors = FALSE
        )
      }
    )
    result <- cmd_execute(list(action = "translate-validate", language = "es"))
    expect_match(result, "All translations are valid")
  })

  it("remind reports stale issues when found", {
    local_mocked_bindings(
      gt_remind_stale = function(...) {
        list(
          list(url = "https://x/y/1", title = "Onboarding ada", days = 45L),
          list(url = "https://x/y/2", title = "Offboarding bob", days = 60L)
        )
      }
    )
    result <- cmd_execute(list(action = "remind"))
    expect_type(result, "character")
    expect_true(grepl("Reminded 2 stale", result, fixed = TRUE))
    expect_true(grepl("Onboarding ada", result, fixed = TRUE))
    expect_true(grepl("45 days", result, fixed = TRUE))
  })

  it("remind reports all-clear with no stale issues", {
    local_mocked_bindings(
      gt_remind_stale = function(...) list()
    )
    result <- cmd_execute(list(action = "remind"))
    expect_match(result, "all caught up")
  })

  it("invite confirms a known team", {
    local_mocked_bindings(
      load_teams_config = function() {
        list(teams = list(list(slug = "website"), list(slug = "blog")))
      },
      team_list_slugs = function(config) c("website", "blog"),
      gt_invite = function(...) invisible(NULL)
    )
    result <- cmd_execute(list(
      action = "invite",
      username = "ada",
      team = "website"
    ))
    expect_true(grepl("@ada", result, fixed = TRUE))
    expect_true(grepl("website", result, fixed = TRUE))
  })

  it("invite rejects an unknown team", {
    local_mocked_bindings(
      load_teams_config = function() list(),
      team_list_slugs = function(config) c("website", "blog"),
      gt_invite = function(...) stop("must not be called")
    )
    result <- cmd_execute(list(
      action = "invite",
      username = "ada",
      team = "rocketry"
    ))
    expect_match(result, "Unknown team")
  })

  it("offboard confirms a known team", {
    local_mocked_bindings(
      load_teams_config = function() list(),
      team_list_slugs = function(config) "website",
      gt_create_offboarding = function(...) invisible(NULL)
    )
    result <- cmd_execute(list(
      action = "offboard",
      username = "ada",
      team = "website"
    ))
    expect_match(result, "Offboarding initiated")
  })

  it("slack-invite delegates to slack_invite_request", {
    local_mocked_bindings(
      slack_invite_request = function(email) {
        glue::glue("Requested: {email}")
      }
    )
    result <- cmd_execute(list(action = "slack-invite", email = "ada@x.com"))
    expect_match(result, "ada@x.com")
  })
})
