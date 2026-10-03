describe("chapter_classify_status", {
  it("puts upcoming events ahead of everything else", {
    expect_identical(
      chapter_classify_status(
        2,
        as.Date("2020-01-01"),
        as.Date("2019-01-01"),
        as.Date("2026-01-01")
      ),
      "active with upcoming events"
    )
  })

  it("calls a chapter with a recent event active", {
    expect_identical(
      chapter_classify_status(
        0,
        as.Date("2026-05-01"),
        as.Date("2019-01-01"),
        as.Date("2026-01-01")
      ),
      "active in the past 6 months"
    )
  })
})

describe("prepare_inactivity_emails", {
  inactive_chapters <- function() {
    data.frame(
      name = c("RLadies+ Oslo", "RLadies+ Lima"),
      urlname = c("rladies-oslo", "rladies-lima"),
      status = c("inactive", "inactive"),
      stringsAsFactors = FALSE
    )
  }

  it("sends the guide's wording and the guide's subject", {
    local_guide_template_text(paste(
      "SUBJECT: Your chapter has no recent activity, do you need help?",
      "",
      "BODY OF THE MESSAGE:",
      "",
      "Dear organisers,",
      "",
      "Is there anything we could do to help you?",
      sep = "\n"
    ))
    expect_message(
      emails <- prepare_inactivity_emails(inactive_chapters()),
      "2 emails prepared"
    )
    expect_identical(
      emails$subject,
      rep("Your chapter has no recent activity, do you need help?", 2)
    )
    expect_match(emails$body[1], "Is there anything we could do to help you?")
    expect_false(grepl("deactivated", emails$body[1]))
  })

  it("addresses each chapter's own mailbox", {
    local_guide_template_text("SUBJECT: Hello\n\nBODY OF THE MESSAGE:\n\nHi.")
    expect_message(emails <- prepare_inactivity_emails(inactive_chapters()))
    expect_identical(
      emails$email,
      c("rladies-oslo@rladies.org", "rladies-lima@rladies.org")
    )
  })

  it("ignores chapters that are not inactive", {
    chapters <- inactive_chapters()
    chapters$status <- c("inactive", "active with upcoming events")
    local_guide_template_text("SUBJECT: Hello\n\nBODY OF THE MESSAGE:\n\nHi.")
    expect_message(emails <- prepare_inactivity_emails(chapters))
    expect_identical(emails$chapter, "RLadies+ Oslo")
  })

  it("says so and sends nothing when every chapter is active", {
    chapters <- inactive_chapters()
    chapters$status <- rep("active in the past 6 months", 2)
    expect_message(
      emails <- prepare_inactivity_emails(chapters),
      "No inactive chapters"
    )
    expect_identical(nrow(emails), 0L)
  })

  it("can send the retirement notice instead", {
    asked <- NULL
    local_mocked_bindings(
      guide_template_fetch = function(name, base_url = NULL) {
        asked <<- name
        "SUBJECT: Retirement\n\nBODY OF THE MESSAGE:\n\nScheduled."
      }
    )
    expect_message(
      emails <- prepare_inactivity_emails(
        inactive_chapters(),
        template = "chapter-retirement-scheduled"
      )
    )
    expect_identical(asked, "chapter-retirement-scheduled")
    expect_identical(emails$subject, rep("Retirement", 2))
  })

  it("refuses to invent a subject the guide did not give", {
    local_guide_template_text("Dear organisers,\n\nNo subject here.")
    expect_error(
      prepare_inactivity_emails(inactive_chapters()),
      "no subject line"
    )
  })

  it("does not claim to have sent anything it did not send", {
    local_guide_template_text("SUBJECT: Hello\n\nBODY OF THE MESSAGE:\n\nHi.")
    expect_message(
      prepare_inactivity_emails(inactive_chapters(), dry_run = FALSE),
      "does not send these itself"
    )
  })
})
