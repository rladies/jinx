#' Normalise channel copy for comparison
#'
#' Slack does not hand back what you send: `&`, `<` and `>` come back
#' HTML-escaped, and a bare URL is rewritten as `<https://...>`. Comparing
#' raw text would therefore report a change that was never made, and
#' would keep reporting it on every pass.
#'
#' @param x A topic or purpose string.
#' @return The string with Slack's own rewriting undone and whitespace
#'   collapsed.
#' @keywords internal
#' @noRd
NULL

#' Read the reviewed channel copy proposals
#'
#' @param workspace Either `"organiser"` or `"community"`.
#' @param path Optional path to the proposals CSV, for testing.
#' @return A data frame of proposals for that workspace, excluding
#'   channels that do not exist yet.
#' @export
channel_copy_proposals <- function(
  workspace = c("organiser", "community"),
  path = NULL
) {
  workspace <- match.arg(workspace)
  path <- path %||%
    system.file(
      "extdata",
      "channel-copy.csv",
      package = "jinx",
      mustWork = TRUE
    )
  props <- utils::read.csv(path, colClasses = "character")
  props <- props[props$workspace == workspace & props$is_new_channel == "0", ]
  props[order(props$channel), ]
}

#' Read the reviewed channel rename proposals
#'
#' @inheritParams channel_copy_proposals
#' @return A data frame of `old`/`new` channel names for that workspace.
#' @export
channel_rename_proposals <- function(
  workspace = c("organiser", "community"),
  path = NULL
) {
  workspace <- match.arg(workspace)
  path <- path %||%
    system.file(
      "extdata",
      "channel-renames.csv",
      package = "jinx",
      mustWork = TRUE
    )
  renames <- utils::read.csv(path, colClasses = "character")
  renames[renames$workspace == workspace, ]
}

#' Index a workspace's public channels
#'
#' Shapes the paginated output of the internal `slack_conversations_list()`
#' helper into the frame the copy plan compares against.
#'
#' @inheritParams channel_copy_proposals
#' @param channels Optional pre-fetched channel list, for testing.
#' @return A data frame with `id`, `name`, `topic`, `purpose` and
#'   `is_member`.
#' @export
slack_channel_index <- function(
  workspace = c("organiser", "community"),
  channels = NULL
) {
  workspace <- match.arg(workspace)
  channels <- channels %||%
    slack_conversations_list(team_id = NULL, workspace = workspace)

  data.frame(
    id = vapply(channels, function(x) x$id, character(1)),
    name = vapply(channels, function(x) x$name, character(1)),
    topic = vapply(channels, function(x) x$topic$value %||% "", character(1)),
    purpose = vapply(
      channels,
      function(x) x$purpose$value %||% "",
      character(1)
    ),
    is_member = vapply(channels, function(x) isTRUE(x$is_member), logical(1)),
    stringsAsFactors = FALSE
  )
}

copy_normalise <- function(x) {
  x <- as.character(x %||% "")
  x <- gsub("<(https?://[^>|]*)>", "\\1", x)
  x <- gsub("<(https?://[^>|]*)\\|[^>]*>", "\\1", x)
  x <- gsub("&amp;", "&", x, fixed = TRUE)
  x <- gsub("&lt;", "<", x, fixed = TRUE)
  x <- gsub("&gt;", ">", x, fixed = TRUE)
  x <- gsub("&quot;", "\"", x, fixed = TRUE)
  x <- gsub("&#39;", "'", x, fixed = TRUE)
  trimws(gsub("[[:space:]]+", " ", x))
}

plan_row <- function(
  channel,
  id,
  field,
  method,
  from,
  to,
  recorded,
  is_member = TRUE
) {
  status <- if (
    !nzchar(to) || identical(copy_normalise(to), copy_normalise(from))
  ) {
    "unchanged"
  } else if (!identical(copy_normalise(recorded), copy_normalise(from))) {
    "drift"
  } else {
    "apply"
  }
  data.frame(
    channel = channel,
    id = id,
    field = field,
    method = method,
    from = from,
    to = to,
    status = status,
    is_member = is_member,
    stringsAsFactors = FALSE
  )
}

copy_plan_rows <- function(props, index) {
  fields <- list(
    list(field = "topic", method = "conversations.setTopic", live = "topic"),
    list(
      field = "description",
      method = "conversations.setPurpose",
      live = "purpose"
    )
  )
  rows <- list()

  for (i in seq_len(nrow(props))) {
    prop <- props[i, ]
    hit <- index[index$name == prop$channel, ]
    if (nrow(hit) == 0) {
      rows[[length(rows) + 1]] <- data.frame(
        channel = prop$channel,
        id = NA_character_,
        field = "channel",
        method = NA_character_,
        from = "",
        to = "",
        status = "missing",
        is_member = TRUE,
        stringsAsFactors = FALSE
      )
      next
    }
    for (spec in fields) {
      rows[[length(rows) + 1]] <- plan_row(
        prop$channel,
        hit$id[1],
        spec$field,
        spec$method,
        hit[[spec$live]][1],
        prop[[paste0(spec$field, "_new")]],
        prop[[paste0(spec$field, "_now")]],
        hit$is_member[1]
      )
    }
  }

  do.call(rbind, rows)
}

rename_plan_rows <- function(renames, index) {
  rows <- list()

  for (i in seq_len(nrow(renames))) {
    rn <- renames[i, ]
    hit <- index[index$name == rn$old, ]
    status <- if (nrow(hit) == 0) {
      if (any(index$name == rn$new)) "unchanged" else "missing"
    } else {
      "apply"
    }
    rows[[length(rows) + 1]] <- data.frame(
      channel = rn$old,
      id = if (nrow(hit) > 0) hit$id[1] else NA_character_,
      field = "name",
      method = "conversations.rename",
      from = rn$old,
      to = rn$new,
      status = status,
      is_member = if (nrow(hit) > 0) hit$is_member[1] else TRUE,
      stringsAsFactors = FALSE
    )
  }

  do.call(rbind, rows)
}

#' Plan the channel copy and rename pass for a workspace
#'
#' Compares the reviewed proposals against the workspace's live state and
#' classifies every intended change. A row is `"unchanged"` when Slack
#' already holds the proposed value, `"drift"` when the live value no
#' longer matches what the review recorded (someone edited it since, so
#' the proposal may be stale), `"missing"` when the channel is not in the
#' workspace, and `"apply"` otherwise.
#'
#' Renames are planned last so a rename cannot hide the channel from the
#' copy rows in the same pass.
#'
#' @inheritParams channel_copy_proposals
#' @param index Optional pre-fetched channel index, for testing.
#' @param proposals,renames Optional proposal data frames, for testing.
#' @return A data frame of planned changes.
#' @export
channel_copy_plan <- function(
  workspace = c("organiser", "community"),
  index = NULL,
  proposals = NULL,
  renames = NULL
) {
  workspace <- match.arg(workspace)
  index <- index %||% slack_channel_index(workspace)
  proposals <- proposals %||% channel_copy_proposals(workspace)
  renames <- renames %||% channel_rename_proposals(workspace)

  rbind(
    copy_plan_rows(proposals, index),
    rename_plan_rows(renames, index)
  )
}

apply_body <- function(row) {
  value <- switch(
    row$field,
    topic = list(channel = row$id, topic = row$to),
    description = list(channel = row$id, purpose = row$to),
    name = list(channel = row$id, name = row$to)
  )
  value
}

#' Apply a channel copy plan
#'
#' Only rows with status `"apply"` are sent to Slack. Everything else is
#' returned untouched so the caller keeps a full record of what was
#' skipped and why.
#'
#' @param plan A plan from [channel_copy_plan()].
#' @param token Slack bot token.
#' @param dry_run When `TRUE` (the default), report what would be sent
#'   without calling Slack.
#' @param skip Channel names to leave alone.
#' @param join Join channels the bot is not a member of first. Slack
#'   refuses `conversations.setTopic`, `setPurpose` and `rename` with
#'   `not_in_channel` otherwise.
#' @param user_token Optional Slack user token used for `rename` rows
#'   only. Slack refuses `conversations.rename` from a bot token for a
#'   channel the bot did not create; a grant from a workspace owner
#'   passes that check. Topics and descriptions always use `token`.
#' @param include_drift Also apply rows whose live value has changed
#'   since the review. Off by default: drift means someone edited the
#'   channel after the copy was written, so applying overwrites the newer
#'   text with older reviewed text.
#' @return `plan` with `applied` and `error` columns added.
#' @export
channel_copy_apply <- function(
  plan,
  token,
  dry_run = TRUE,
  skip = character(),
  join = TRUE,
  include_drift = FALSE,
  user_token = NULL
) {
  plan$applied <- FALSE
  plan$error <- NA_character_
  plan$status[plan$channel %in% skip] <- "skipped"
  wanted <- if (include_drift) c("apply", "drift") else "apply"
  todo <- which(plan$status %in% wanted)

  if (dry_run) {
    cli::cli_alert_info(
      "Dry run: {length(todo)} change{?s} would be sent to Slack."
    )
    return(plan)
  }

  if (join) {
    joined <- unique(plan$id[todo][!plan$is_member[todo]])
    for (id in joined[!is.na(joined)]) {
      try(
        slack_api_call(token, "conversations.join", list(channel = id)),
        silent = TRUE
      )
    }
  }

  for (i in todo) {
    use <- if (identical(plan$field[i], "name") && !is.null(user_token)) {
      user_token
    } else {
      token
    }
    outcome <- tryCatch(
      {
        slack_api_call(use, plan$method[i], apply_body(plan[i, ]))
        NA_character_
      },
      error = function(e) conditionMessage(e)
    )
    plan$applied[i] <- is.na(outcome)
    plan$error[i] <- outcome
  }

  cli::cli_alert_success("Applied {sum(plan$applied)} change{?s}.")
  plan
}
