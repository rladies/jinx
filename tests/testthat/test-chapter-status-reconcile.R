write_chapter <- function(dir, filename, ...) {
  jsonlite::write_json(
    list(...),
    file.path(dir, filename),
    auto_unbox = TRUE,
    pretty = TRUE
  )
}

health_frame <- function(...) {
  rows <- list(...)
  do.call(
    rbind,
    lapply(rows, function(r) {
      data.frame(
        chapter = r[[1]],
        last_event = as.Date(r[[2]]),
        months_inactive = r[[3]],
        status = if (r[[3]] < 6) "active" else "inactive",
        stringsAsFactors = FALSE
      )
    })
  )
}

describe("chapter_status_reconcile()", {
  it("promotes a prospective chapter that is running events", {
    dir <- withr::local_tempdir()
    write_chapter(
      dir,
      "usa-colorado-aurora.json",
      urlname = "rladies-aurora",
      status = "prospective"
    )
    health <- health_frame(list("rladies-aurora", "2026-09-01", 0L))
    out <- chapter_status_reconcile(dir, health = health)
    expect_equal(out$action, "promote to active")
  })

  it("flags an active chapter that has gone quiet", {
    dir <- withr::local_tempdir()
    write_chapter(
      dir,
      "norway-oslo.json",
      urlname = "rladies-oslo",
      status = "active"
    )
    health <- health_frame(list("rladies-oslo", "2026-01-01", 8L))
    out <- chapter_status_reconcile(dir, health = health)
    expect_equal(out$action, "flag quiet")
  })

  it("marks inactive a chapter with nothing for over a year", {
    dir <- withr::local_tempdir()
    write_chapter(
      dir,
      "norway-oslo.json",
      urlname = "rladies-oslo",
      status = "active"
    )
    health <- health_frame(list("rladies-oslo", "2024-01-01", 20L))
    out <- chapter_status_reconcile(dir, health = health)
    expect_equal(out$action, "mark inactive")
  })

  it("marks inactive a chapter that never had any event", {
    dir <- withr::local_tempdir()
    write_chapter(dir, "italy-pisa.json", status = "prospective")
    health <- health_frame(list("rladies-oslo", "2026-09-01", 0L))
    out <- chapter_status_reconcile(dir, health = health)
    expect_equal(out$action, "mark inactive")
  })

  it("spares a chapter too young to have run anything yet", {
    dir <- withr::local_tempdir()
    write_chapter(dir, "italy-pisa.json", status = "prospective")
    health <- health_frame(list("rladies-oslo", "2026-09-01", 0L))
    out <- chapter_status_reconcile(
      dir,
      health = health,
      initiated = Sys.Date() - 30
    )
    expect_true(is.na(out$action))
  })

  it("leaves a retired chapter alone however quiet it is", {
    dir <- withr::local_tempdir()
    write_chapter(
      dir,
      "austria-linz.json",
      urlname = "rladies-linz",
      status = "retired on 29-09-2019"
    )
    health <- health_frame(list("rladies-linz", "2019-01-01", 80L))
    out <- chapter_status_reconcile(dir, health = health)
    expect_true(is.na(out$action))
  })

  it("does not re-mark a chapter that is already inactive", {
    dir <- withr::local_tempdir()
    write_chapter(
      dir,
      "norway-oslo.json",
      urlname = "rladies-oslo",
      status = "inactive"
    )
    health <- health_frame(list("rladies-oslo", "2024-01-01", 20L))
    out <- chapter_status_reconcile(dir, health = health)
    expect_true(is.na(out$action))
  })

  it("leaves an active chapter with recent events alone", {
    dir <- withr::local_tempdir()
    write_chapter(
      dir,
      "norway-oslo.json",
      urlname = "rladies-oslo",
      status = "active"
    )
    health <- health_frame(list("rladies-oslo", "2026-09-01", 1L))
    out <- chapter_status_reconcile(dir, health = health)
    expect_true(is.na(out$action))
  })

  it("records no last event when the chapter is not in the archive", {
    dir <- withr::local_tempdir()
    write_chapter(
      dir,
      "italy-pisa.json",
      urlname = "rladies-pisa",
      status = "prospective"
    )
    health <- health_frame(list("rladies-other", "2026-09-01", 0L))
    out <- chapter_status_reconcile(dir, health = health)
    expect_true(is.na(out$last_event))
  })

  it("promotes a retired chapter that has started running events again", {
    dir <- withr::local_tempdir()
    write_chapter(
      dir,
      "austria-linz.json",
      urlname = "rladies-linz",
      status = "retired on 29-09-2019"
    )
    health <- health_frame(list("rladies-linz", "2026-08-01", 1L))
    out <- chapter_status_reconcile(dir, health = health)
    expect_equal(out$action, "promote to active")
  })

  it("matches urlnames case-insensitively", {
    dir <- withr::local_tempdir()
    write_chapter(
      dir,
      "saudi-arabia-jeddah.json",
      urlname = "RLadiesJeddah",
      status = "prospective"
    )
    health <- health_frame(list("rladiesjeddah", "2026-09-01", 0L))
    out <- chapter_status_reconcile(dir, health = health)
    expect_equal(out$action, "promote to active")
  })

  it("includes chapters with no urlname, which can have no events", {
    dir <- withr::local_tempdir()
    write_chapter(dir, "italy-pisa.json", status = "prospective")
    health <- health_frame(list("rladies-oslo", "2026-09-01", 0L))
    out <- chapter_status_reconcile(dir, health = health)
    expect_equal(nrow(out), 1)
    expect_true(is.na(out$urlname))
  })

  it("respects a custom inactivity window", {
    dir <- withr::local_tempdir()
    write_chapter(
      dir,
      "norway-oslo.json",
      urlname = "rladies-oslo",
      status = "active"
    )
    health <- health_frame(list("rladies-oslo", "2026-01-01", 9L))
    expect_true(is.na(
      chapter_status_reconcile(dir, health = health, 12)$action
    ))
    expect_equal(
      chapter_status_reconcile(dir, health = health, months = 6)$action,
      "flag quiet"
    )
  })
})

describe("chapter_status_reconcile_report()", {
  it("says so when nothing needs doing", {
    dir <- withr::local_tempdir()
    write_chapter(
      dir,
      "norway-oslo.json",
      urlname = "rladies-oslo",
      status = "active"
    )
    health <- health_frame(list("rladies-oslo", "2026-09-01", 1L))
    out <- chapter_status_reconcile(dir, health = health)
    expect_match(
      chapter_status_reconcile_report(out),
      "matches its activity",
      fixed = TRUE
    )
  })

  it("separates promotions from inactivity flags", {
    dir <- withr::local_tempdir()
    write_chapter(
      dir,
      "usa-colorado-aurora.json",
      urlname = "rladies-aurora",
      status = "prospective"
    )
    write_chapter(
      dir,
      "norway-oslo.json",
      urlname = "rladies-oslo",
      status = "active"
    )
    health <- health_frame(
      list("rladies-aurora", "2026-09-01", 0L),
      list("rladies-oslo", "2026-01-01", 8L)
    )
    report <- chapter_status_reconcile_report(
      chapter_status_reconcile(dir, health = health)
    )
    expect_match(
      report,
      "Running events but not marked active (1)",
      fixed = TRUE
    )
    expect_match(report, "No Meetup event in 6 months (1)", fixed = TRUE)
    expect_match(report, "a real gap", fixed = TRUE)
  })
})

describe("chapter_initiated_date()", {
  local_repo <- function(env = parent.frame()) {
    dir <- withr::local_tempdir(.local_envir = env)
    run <- function(...) {
      system2("git", c("-C", shQuote(dir), ...), stdout = FALSE, stderr = FALSE)
    }
    run("init", "-q")
    run("config", "user.email", "t@example.com")
    run("config", "user.name", "T")
    dir
  }

  it("reports the date a chapter file was added", {
    dir <- local_repo()
    writeLines("{}", file.path(dir, "oslo.json"))
    system2(
      "git",
      c("-C", shQuote(dir), "add", "oslo.json"),
      stdout = FALSE,
      stderr = FALSE
    )
    system2(
      "git",
      c("-C", shQuote(dir), "commit", "-q", "-m", "add"),
      stdout = FALSE,
      stderr = FALSE
    )
    out <- chapter_initiated_date("oslo.json", repo = dir, bulk_import = NULL)
    expect_equal(out, Sys.Date())
  })

  it("follows a rename rather than resetting the date", {
    dir <- local_repo()
    run <- function(..., when = NULL) {
      withr::with_envvar(
        c(GIT_COMMITTER_DATE = when),
        system2(
          "git",
          c("-C", shQuote(dir), ...),
          stdout = FALSE,
          stderr = FALSE
        )
      )
    }
    writeLines("{}", file.path(dir, "old.json"))
    run("add", "old.json")
    run("commit", "-q", "-m", "add", when = "2024-01-02T00:00:00")
    run("mv", "old.json", "new.json")
    run("commit", "-q", "-m", "rename")

    followed <- chapter_initiated_date(
      "new.json",
      repo = dir,
      bulk_import = NULL
    )
    expect_equal(followed, as.Date("2024-01-02"))
  })

  it("returns NA for the bulk import date", {
    dir <- local_repo()
    run <- function(..., when = NULL) {
      withr::with_envvar(
        c(GIT_COMMITTER_DATE = when),
        system2(
          "git",
          c("-C", shQuote(dir), ...),
          stdout = FALSE,
          stderr = FALSE
        )
      )
    }
    writeLines("{}", file.path(dir, "pisa.json"))
    run("add", "pisa.json")
    run("commit", "-q", "-m", "import", when = "2023-01-04T00:00:00")
    out <- chapter_initiated_date("pisa.json", repo = dir)
    expect_true(is.na(out))
  })

  it("returns NA for a file git knows nothing about", {
    dir <- local_repo()
    expect_true(is.na(chapter_initiated_date("nope.json", repo = dir)))
  })
})
