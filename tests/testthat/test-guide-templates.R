library(httr2)

describe("guide_base_url", {
  it("points at the published guide", {
    expect_identical(guide_base_url(), "https://guide.rladies.org")
  })

  it("can be pointed at a local build", {
    withr::local_options(jinx.guide_url = "http://localhost:1313")
    expect_identical(guide_base_url(), "http://localhost:1313")
  })
})

describe("guide_template_fetch", {
  it("asks for the template under /templates", {
    asked <- NULL
    local_mocked_responses(function(req) {
      asked <<- req$url
      markdown_response("Dear organisers,")
    })
    guide_template_fetch("chapter-reactivation")
    expect_identical(
      asked,
      "https://guide.rladies.org/templates/chapter-reactivation.md"
    )
  })

  it("refuses an HTML page served where markdown was expected", {
    local_mocked_responses(list(response(
      headers = list(`content-type` = "text/html; charset=utf-8"),
      body = charToRaw("<!DOCTYPE html><html>Page not found</html>")
    )))
    expect_error(guide_template_fetch("chapter-reactivation"), "text/html")
  })

  it("accepts plain text as well as markdown", {
    local_mocked_responses(list(response(
      headers = list(`content-type` = "text/plain"),
      body = charToRaw("Dear organisers,")
    )))
    expect_identical(
      guide_template_fetch("chapter-reactivation"),
      "Dear organisers,"
    )
  })

  it("returns the markdown the guide serves", {
    local_mocked_responses(list(markdown_response("Hi <<NAME>>,")))
    expect_identical(
      guide_template_fetch("chapter-general-info"),
      "Hi <<NAME>>,"
    )
  })

  it("fails loudly rather than falling back to a copy", {
    local_mocked_responses(function(req) stop("network down"))
    expect_error(
      guide_template_fetch("chapter-reactivation"),
      "Could not fetch"
    )
  })

  it("refuses an empty template", {
    local_mocked_responses(list(markdown_response("  \n ")))
    expect_error(guide_template_fetch("chapter-reactivation"), "empty")
  })
})

describe("guide_template_split", {
  it("separates the subject from the body", {
    parts <- guide_template_split(paste(
      "SUBJECT: Your chapter has no recent activity",
      "",
      "BODY OF THE MESSAGE:",
      "",
      "Dear organisers,",
      "",
      "Hope you are well!",
      sep = "\n"
    ))
    expect_identical(parts$subject, "Your chapter has no recent activity")
    expect_identical(parts$body, "Dear organisers,\n\nHope you are well!")
  })

  it("reports no subject for a template that carries none", {
    parts <- guide_template_split("\nHi <<FIRST_NAME>>,\n\nThanks.\n")
    expect_identical(parts$subject, "")
    expect_identical(parts$body, "Hi <<FIRST_NAME>>,\n\nThanks.")
  })

  it("takes everything after the subject when no body marker is given", {
    parts <- guide_template_split("SUBJECT: Hello\n\nDear organisers,")
    expect_identical(parts$subject, "Hello")
    expect_identical(parts$body, "Dear organisers,")
  })

  it("gives an empty body for a subject on its own", {
    parts <- guide_template_split("SUBJECT: Hello")
    expect_identical(parts$subject, "Hello")
    expect_identical(parts$body, "")
  })
})

describe("guide_template", {
  it("returns the guide's text, trimmed", {
    local_guide_template_text("\nCanonical description.\n\n")
    expect_identical(
      guide_template("meetup-group-description"),
      "Canonical description."
    )
  })

  it("fills the placeholders it is given", {
    local_guide_template_text("Hi <<FIRST_NAME>>, welcome to <<CITY>>!")
    expect_identical(
      guide_template(
        "chapter-onboarding-welcome",
        list(FIRST_NAME = "Ada", CITY = "Oslo")
      ),
      "Hi Ada, welcome to Oslo!"
    )
  })

  it("leaves the placeholders a human is meant to fill", {
    local_guide_template_text("Dear <<CONTACT_NAME>>, from <<YOUR_NAME>>.")
    expect_identical(
      guide_template("sponsor-approach-letter", list(CONTACT_NAME = "Ada")),
      "Dear Ada, from <<YOUR_NAME>>."
    )
  })

  it("does not read an email header out of a template that is not email", {
    local_guide_template_text("Tell them SUBJECT: is not a header here.")
    expect_identical(
      guide_template("meetup-group-ready-message"),
      "Tell them SUBJECT: is not a header here."
    )
  })
})

describe("guide_email_template", {
  it("fills placeholders in both subject and body", {
    local_guide_template_text(paste(
      "SUBJECT: Welcome to RLadies+ <<CITY>>",
      "",
      "BODY OF THE MESSAGE:",
      "",
      "Hi <<FIRST_NAME>>, welcome to <<CITY>>!",
      sep = "\n"
    ))
    filled <- guide_email_template(
      "chapter-onboarding-welcome",
      list(FIRST_NAME = "Ada", CITY = "Oslo")
    )
    expect_identical(filled$subject, "Welcome to RLadies+ Oslo")
    expect_identical(filled$body, "Hi Ada, welcome to Oslo!")
    expect_identical(filled$name, "chapter-onboarding-welcome")
  })

  it("refuses to invent a subject the guide did not give", {
    local_guide_template_text("Dear organisers,\n\nNo subject here.")
    expect_error(
      guide_email_template("chapter-general-info"),
      "no subject line"
    )
  })
})
