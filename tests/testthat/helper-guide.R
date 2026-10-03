local_guide_template_text <- function(text, env = parent.frame()) {
  local_mocked_bindings(
    guide_template_fetch = function(name, base_url = NULL) text,
    .env = env
  )
}

markdown_response <- function(text) {
  httr2::response(
    headers = list(`content-type` = "text/markdown; charset=UTF-8"),
    body = charToRaw(text)
  )
}
