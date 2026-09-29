write_chapter <- function(dir, filename, ...) {
  jsonlite::write_json(
    list(...),
    file.path(dir, filename),
    auto_unbox = TRUE,
    pretty = TRUE
  )
}

# Endpoints listed in `exists` resolve; everything else 404s.
local_gh <- function(exists = character(), env = parent.frame()) {
  testthat::local_mocked_bindings(
    chapter_gh_exists = function(endpoint) endpoint %in% exists,
    .env = env
  )
}

describe("chapter_repo_audit()", {
  it("asks gh for an endpoint with a leading slash", {
    dir <- withr::local_tempdir()
    write_chapter(
      dir,
      "norway-oslo.json",
      city = "Oslo",
      social_media = list(github = "rladies/x")
    )
    seen <- character()
    testthat::local_mocked_bindings(
      chapter_gh_exists = function(endpoint) {
        seen <<- c(seen, endpoint)
        FALSE
      }
    )
    chapter_repo_audit(dir)
    expect_true(all(startsWith(seen, "/")))
  })

  it("says nothing about a reference that resolves to a repo", {
    dir <- withr::local_tempdir()
    write_chapter(
      dir,
      "norway-oslo.json",
      city = "Oslo",
      social_media = list(github = "rladies/meetup-presentations_oslo")
    )
    local_gh("/repos/rladies/meetup-presentations_oslo")
    expect_equal(nrow(chapter_repo_audit(dir)), 0)
  })

  it("accepts a bare organisation name", {
    dir <- withr::local_tempdir()
    write_chapter(
      dir,
      "france-paris.json",
      city = "Paris",
      social_media = list(github = "R-Ladies-Paris")
    )
    local_gh("/orgs/R-Ladies-Paris")
    expect_equal(nrow(chapter_repo_audit(dir)), 0)
  })

  it("flags a dead repo and suggests the conventional one", {
    dir <- withr::local_tempdir()
    write_chapter(
      dir,
      "usa-iowa-ames.json",
      city = "Ames",
      social_media = list(github = "rladies/rladies-ames")
    )
    local_gh("/repos/rladies/meetup-presentations_ames")
    out <- chapter_repo_audit(dir)
    expect_equal(out$state, "missing")
    expect_equal(out$suggestion, "rladies/meetup-presentations_ames")
  })

  it("flags a dead repo with no suggestion when none exists", {
    dir <- withr::local_tempdir()
    write_chapter(
      dir,
      "australia-sydney.json",
      city = "Sydney",
      social_media = list(github = "rladies/rladiessydney")
    )
    local_gh(character())
    out <- chapter_repo_audit(dir)
    expect_equal(out$state, "missing")
    expect_true(is.na(out$suggestion))
  })

  it("resolves a full URL rather than calling it dead", {
    dir <- withr::local_tempdir()
    write_chapter(
      dir,
      "brazil-sao-paulo-sao-paulo.json",
      city = "Sao Paulo",
      social_media = list(github = "https://github.com/R-Ladies-Sao-Paulo/")
    )
    local_gh("/orgs/R-Ladies-Sao-Paulo")
    out <- chapter_repo_audit(dir)
    expect_equal(out$state, "url")
    expect_equal(out$suggestion, "R-Ladies-Sao-Paulo")
  })

  it("still calls a full URL dead when it resolves to nothing", {
    dir <- withr::local_tempdir()
    write_chapter(
      dir,
      "gone.json",
      city = "Gone",
      social_media = list(github = "https://github.com/rladies/gone")
    )
    local_gh(character())
    expect_equal(chapter_repo_audit(dir)$state, "missing")
  })

  it("strips a .git suffix and trailing slashes before resolving", {
    dir <- withr::local_tempdir()
    write_chapter(
      dir,
      "x.json",
      city = "X",
      social_media = list(github = "https://github.com/rladies/thing.git")
    )
    local_gh("/repos/rladies/thing")
    out <- chapter_repo_audit(dir)
    expect_equal(out$state, "url")
    expect_equal(out$suggestion, "rladies/thing")
  })

  it("flags a repo name with no owner", {
    dir <- withr::local_tempdir()
    write_chapter(
      dir,
      "botswana-gaborone.json",
      city = "Gaborone",
      social_media = list(github = "meetup_presentations_gaborone")
    )
    local_gh("/repos/rladies/meetup-presentations_gaborone")
    out <- chapter_repo_audit(dir)
    expect_equal(out$state, "missing")
    expect_equal(out$suggestion, "rladies/meetup-presentations_gaborone")
  })

  it("ignores a chapter with no github reference", {
    dir <- withr::local_tempdir()
    write_chapter(dir, "italy-pisa.json", city = "Pisa", social_media = list())
    local_gh(character())
    expect_equal(nrow(chapter_repo_audit(dir)), 0)
  })

  it("transliterates the city when building a suggestion", {
    dir <- withr::local_tempdir()
    write_chapter(
      dir,
      "brazil-ceara-fortaleza.json",
      city = "Vitória",
      social_media = list(github = "rladies/wrong")
    )
    local_gh("/repos/rladies/meetup-presentations_vitoria")
    expect_equal(
      chapter_repo_audit(dir)$suggestion,
      "rladies/meetup-presentations_vitoria"
    )
  })
})

describe("chapter_repo_audit_report()", {
  it("confirms success when everything resolves", {
    dir <- withr::local_tempdir()
    local_gh(character())
    report <- chapter_repo_audit_report(chapter_repo_audit(dir))
    expect_match(
      report,
      "Every chapter GitHub reference resolves",
      fixed = TRUE
    )
  })

  it("separates the fixable from the unknown", {
    dir <- withr::local_tempdir()
    write_chapter(
      dir,
      "usa-iowa-ames.json",
      city = "Ames",
      social_media = list(github = "rladies/rladies-ames")
    )
    write_chapter(
      dir,
      "australia-sydney.json",
      city = "Sydney",
      social_media = list(github = "rladies/rladiessydney")
    )
    local_gh("/repos/rladies/meetup-presentations_ames")
    report <- chapter_repo_audit_report(chapter_repo_audit(dir))
    expect_match(report, "likely replacement", fixed = TRUE)
    expect_match(report, "no obvious replacement", fixed = TRUE)
  })
})

describe("chapter_repo_audit_report()", {
  it("reports a URL-shaped reference separately from the dead ones", {
    dir <- withr::local_tempdir()
    write_chapter(
      dir,
      "live-url.json",
      city = "Sao Paulo",
      social_media = list(github = "https://github.com/R-Ladies-Sao-Paulo/")
    )
    write_chapter(
      dir,
      "dead.json",
      city = "Nowhere",
      social_media = list(github = "rladies/nope")
    )
    local_gh("/orgs/R-Ladies-Sao-Paulo")
    report <- chapter_repo_audit_report(chapter_repo_audit(dir))
    expect_match(report, "Resolves, but written as a URL", fixed = TRUE)
    expect_match(report, "Dead, no obvious replacement", fixed = TRUE)
    expect_match(report, "`R-Ladies-Sao-Paulo`", fixed = TRUE)
  })

  it("keeps a trailing newline", {
    dir <- withr::local_tempdir()
    local_gh(character())
    expect_match(chapter_repo_audit_report(chapter_repo_audit(dir)), "\n$")
  })
})

describe("chapter_repo_audit() organisation prefixes", {
  it("spots an organisation name written as a repo under the org", {
    dir <- withr::local_tempdir()
    write_chapter(
      dir,
      "usa-michigan-east-lansing.json",
      city = "East Lansing",
      social_media = list(github = "rladies/rladies-eastlansing")
    )
    local_gh("/orgs/rladies-eastlansing")
    out <- chapter_repo_audit(dir)
    expect_equal(out$state, "prefixed")
    expect_equal(out$suggestion, "rladies-eastlansing")
  })

  it("prefers the chapter's own organisation over a conventional repo", {
    dir <- withr::local_tempdir()
    write_chapter(
      dir,
      "usa-tennessee-nashville.json",
      city = "Nashville",
      social_media = list(github = "rladies/rladies-nashville")
    )
    local_gh(c(
      "/orgs/rladies-nashville",
      "/repos/rladies/meetup-presentations_nashville"
    ))
    out <- chapter_repo_audit(dir)
    expect_equal(out$suggestion, "rladies-nashville")
  })

  it("still suggests the conventional repo when no organisation exists", {
    dir <- withr::local_tempdir()
    write_chapter(
      dir,
      "uk-manchester.json",
      city = "Manchester",
      social_media = list(github = "rladies/RLadiesManchester")
    )
    local_gh("/repos/rladies/meetup-presentations_manchester")
    out <- chapter_repo_audit(dir)
    expect_equal(out$state, "missing")
    expect_equal(out$suggestion, "rladies/meetup-presentations_manchester")
  })

  it("gives prefixed references their own report section", {
    dir <- withr::local_tempdir()
    write_chapter(
      dir,
      "seattle.json",
      city = "Seattle",
      social_media = list(github = "rladies/rladies-seattle")
    )
    local_gh("/orgs/rladies-seattle")
    report <- chapter_repo_audit_report(chapter_repo_audit(dir))
    expect_match(report, "spurious owner prefix", fixed = TRUE)
    expect_match(report, "`rladies-seattle`", fixed = TRUE)
  })
})
