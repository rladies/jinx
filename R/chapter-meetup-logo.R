#' The branded profile image jinx uploads to new Meetup groups
#'
#' Rendered at 1080x1080 from
#' `logos/social-media/RLadies+ logo_Social media profile picture-Purple
#' background.svg` in `rladies/branding-materials`, which is the source of
#' truth. Meetup accepts GIF, JPEG and PNG but not SVG, so a raster copy
#' has to live here; regenerate it with
#' `inkscape --export-type=png --export-width=1080 --export-height=1080`
#' if the brand asset changes.
#'
#' @return Path to the bundled PNG.
#' @keywords internal
#' @noRd
chapter_meetup_logo_path <- function() {
  path <- system.file(
    "branding",
    "rladies-social-profile.png",
    package = "jinx"
  )
  if (!nzchar(path)) {
    cli::cli_abort("Branded profile image not found in jinx")
  }
  path
}

#' Look up a Meetup group's id from its urlname
#'
#' @param urlname Meetup group urlname.
#' @return The group id.
#' @keywords internal
#' @noRd
chapter_meetup_group_id <- function(urlname) {
  result <- meetupr::meetupr_query(
    "query($urlname: String!) { groupByUrlname(urlname: $urlname) { id } }",
    urlname = urlname
  )
  id <- result$data$groupByUrlname$id %or% NULL
  if (is.null(id)) {
    cli::cli_abort("No Meetup group found at {.val {urlname}}")
  }
  id
}

#' Set a chapter's Meetup group photo to the RLadies+ logo
#'
#' Meetup uploads in two steps: a mutation registers the photo and
#' returns a signed `uploadUrl`, then the bytes are sent to that URL. The
#' mutation is named for event photos, but `photoType` carries a
#' `GROUP_PHOTO` value and `setAsMain` makes it the group's image.
#'
#' @param urlname Meetup group urlname.
#' @param image Path to the image. Defaults to the bundled RLadies+
#'   profile logo.
#' @return The uploaded image path reported by Meetup (invisibly).
#' @export
chapter_meetup_logo_upload <- function(
  urlname,
  image = chapter_meetup_logo_path()
) {
  if (!file.exists(image)) {
    cli::cli_abort("No image at {.path {image}}")
  }

  group_id <- chapter_meetup_group_id(urlname)

  registered <- meetupr::meetupr_query(
    "mutation($input: GroupEventPhotoCreateInput!) {
       createGroupEventPhoto(input: $input) {
         uploadUrl
         imagePath
         error { message }
       }
     }",
    input = list(
      groupId = group_id,
      photoType = "GROUP_PHOTO",
      contentType = "PNG",
      setAsMain = TRUE
    )
  )

  payload <- registered$data$createGroupEventPhoto %or% list()
  if (!is.null(payload$error)) {
    cli::cli_abort(c(
      "Meetup refused the photo for {.val {urlname}}.",
      "x" = payload$error$message %or% "no reason given"
    ))
  }

  upload_url <- payload$uploadUrl %or% NULL
  if (is.null(upload_url)) {
    cli::cli_abort("Meetup returned no upload URL for {.val {urlname}}")
  }

  httr2::request(upload_url) |>
    httr2::req_method("PUT") |>
    httr2::req_headers(`Content-Type` = "image/png") |>
    httr2::req_body_file(image) |>
    httr2::req_perform()

  cli::cli_alert_success("Set the RLadies+ logo on {.val {urlname}}")
  invisible(payload$imagePath %or% NA_character_)
}
