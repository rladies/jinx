#' Build the Jinx RAG index
#'
#' Gathers chunks from every configured source, embeds them with
#' Cloudflare Workers AI, and upserts the vectors into a Vectorize
#' index. The source list is loaded from `inst/config/rag-sources.yml`
#' unless `sources` is supplied directly.
#'
#' @param sources Optional list of source specs (see `load_rag_sources()`).
#' @param account_id Cloudflare account ID. Falls back to env
#'   `CLOUDFLARE_ACCOUNT_ID`, then `cloudflare_account_id()`.
#' @param api_token Cloudflare API token. Defaults to env
#'   `CLOUDFLARE_API_TOKEN`.
#' @param index_name Vectorize index. Defaults to env `VECTORIZE_INDEX`
#'   or `"rladies-content"`.
#' @param batch_size Number of chunks per embed/upsert call.
#' @param model Workers AI embedding model.
#' @return Invisibly: list with `chunks` (total) and `upsert` (API response).
#' @export
rag_index_build <- function(
  sources = NULL,
  account_id = NULL,
  api_token = Sys.getenv("CLOUDFLARE_API_TOKEN"),
  index_name = NULL,
  batch_size = 50L,
  model = "@cf/baai/bge-base-en-v1.5"
) {
  if (!nzchar(api_token)) {
    cli::cli_abort("CLOUDFLARE_API_TOKEN is not set.")
  }
  account_id <- account_id %||% Sys.getenv("CLOUDFLARE_ACCOUNT_ID", unset = NA)
  if (is.na(account_id) || !nzchar(account_id)) {
    account_id <- cloudflare_account_id(api_token)
  }
  index_name <- index_name %||%
    Sys.getenv("VECTORIZE_INDEX", unset = "rladies-content")
  if (is.null(sources)) {
    sources <- load_rag_sources()
  }

  chunks <- gather_all_chunks(sources)
  cli::cli_alert_success("Total chunks: {length(chunks)}")
  if (length(chunks) == 0L) {
    cli::cli_abort("No chunks produced - aborting upsert.")
  }

  vectors <- embed_chunks(chunks, account_id, api_token, model, batch_size)
  result <- cloudflare_vectorize_upsert(
    vectors,
    account_id = account_id,
    api_token = api_token,
    index_name = index_name
  )
  cli::cli_alert_success(
    "Upserted {length(vectors)} vectors to {.field {index_name}}."
  )
  invisible(list(chunks = chunks, upsert = result))
}

gather_all_chunks <- function(sources) {
  per_source <- lapply(sources, function(src) {
    cli::cli_alert_info("Gathering {.field {src$source_type}} ({src$type})")
    src_chunks <- gather_rag_source(src)
    lapply(src_chunks, function(c) {
      c$source_type <- src$source_type
      c
    })
  })
  unlist(per_source, recursive = FALSE) %||% list()
}

embed_chunks <- function(chunks, account_id, api_token, model, batch_size) {
  total <- length(chunks)
  batches <- split(chunks, ceiling(seq_along(chunks) / batch_size))
  per_batch <- Map(
    function(batch, i) {
      embeds <- cloudflare_embed(
        vapply(batch, function(c) c$text, character(1)),
        account_id = account_id,
        api_token = api_token,
        model = model
      )
      cli::cli_alert_info(
        "Embedded {min(i * batch_size, total)}/{total}"
      )
      Map(chunk_to_vector, batch, embeds)
    },
    batches,
    seq_along(batches)
  )
  unlist(per_batch, recursive = FALSE)
}

chunk_to_vector <- function(chunk, embedding) {
  list(
    id = rag_chunk_id(chunk$repo, chunk$path, chunk$chunk_idx),
    values = embedding,
    metadata = list(
      url = chunk$url,
      title = chunk$title,
      heading = chunk$heading,
      repo = chunk$repo,
      path = chunk$path,
      text = chunk$text,
      source_type = chunk$source_type,
      date = chunk$date %||% 0L,
      lastmod = chunk$lastmod %||% chunk$date %||% 0L
    )
  )
}

#' Load the configured RAG source list
#'
#' @return List of source specs.
#' @export
load_rag_sources <- function() {
  path <- system.file("config", "rag-sources.yml", package = "jinx")
  if (!nzchar(path)) {
    cli::cli_abort("rag-sources.yml not found in jinx package.")
  }
  yaml::read_yaml(path)
}

#' Dispatch a source spec to the appropriate gather function
#'
#' Looks up `gather_<type>()` where `<type>` has dashes replaced by
#' underscores. Sources extend the indexer by defining a new
#' `gather_<type>(src)` function.
#'
#' @param src Source spec list (must have `type`).
#' @return List of chunk records (with `chunk_idx` set per document).
#' @export
gather_rag_source <- function(src) {
  fn_name <- paste0("gather_", gsub("-", "_", src$type))
  fn <- tryCatch(
    get(fn_name, envir = asNamespace("jinx")),
    error = function(e) NULL
  )
  if (is.null(fn)) {
    cli::cli_warn("Unknown source type: {.val {src$type}}")
    return(list())
  }
  fn(src)
}
