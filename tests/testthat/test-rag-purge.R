purge_repo <- function(
  full_name = "rladies/secret-plans",
  private = TRUE,
  archived = FALSE
) {
  list(
    full_name = full_name,
    private = private,
    archived = archived,
    html_url = paste0("https://github.com/", full_name),
    description = "Not for the index"
  )
}

purge_readme <- function(sections = 3) {
  body <- paste(
    vapply(
      seq_len(sections),
      function(i) {
        paste0(
          "## Section ",
          i,
          "\n\n",
          strrep("This section is long enough to survive chunking. ", 8)
        )
      },
      character(1)
    ),
    collapse = "\n\n"
  )
  paste0(
    "# Title\n\n",
    strrep("Intro prose that is also long enough. ", 8),
    "\n\n",
    body
  )
}

describe("rag_repo_is_indexable", {
  it("accepts a live public repo", {
    expect_true(rag_repo_is_indexable(purge_repo(private = FALSE)))
  })

  it("rejects a private repo", {
    expect_false(rag_repo_is_indexable(purge_repo(private = TRUE)))
  })

  it("rejects archived and disabled repos as before", {
    expect_false(
      rag_repo_is_indexable(purge_repo(private = FALSE, archived = TRUE))
    )
    expect_false(
      rag_repo_is_indexable(list(private = FALSE, disabled = TRUE))
    )
  })

  it("treats a repo with no private flag as public", {
    expect_true(rag_repo_is_indexable(list(full_name = "rladies/x")))
  })
})

describe("gather_github_org", {
  it("leaves private repos out of the chunks", {
    withr::local_envvar(GITHUB_TOKEN = "token")
    local_mocked_bindings(
      gh = function(endpoint, ...) {
        if (grepl("teams", endpoint, fixed = TRUE)) {
          return(list())
        }
        list(purge_repo(private = TRUE), purge_repo("rladies/open", FALSE))
      },
      .package = "gh"
    )
    local_mocked_bindings(gh_fetch_readme = function(...) NULL)

    chunks <- gather_github_org(list(org = "rladies"))
    repos <- vapply(chunks, function(c) c$repo, character(1))
    expect_identical(unique(repos), "rladies/open")
    expect_false(any(grepl("secret-plans", repos)))
  })
})

describe("rag_private_repo_ids", {
  it("covers the metadata chunk and the README chunks", {
    local_mocked_bindings(
      gh_fetch_readme = function(...) purge_readme(3)
    )
    ids <- rag_private_repo_ids(purge_repo(), "token")
    expect_true(rag_chunk_id("rladies/secret-plans", "_meta", 0L) %in% ids)
    expect_true(rag_chunk_id("rladies/secret-plans", "README.md", 0L) %in% ids)
  })

  it("deletes past the end, for a README that has since shrunk", {
    local_mocked_bindings(gh_fetch_readme = function(...) purge_readme(1))
    ids <- rag_private_repo_ids(purge_repo(), "token")
    beyond <- rag_chunk_id("rladies/secret-plans", "README.md", 10L)
    expect_true(beyond %in% ids)
  })

  it("still covers the metadata chunk when there is no README", {
    local_mocked_bindings(gh_fetch_readme = function(...) NULL)
    ids <- rag_private_repo_ids(purge_repo(), "token")
    expect_identical(ids, rag_chunk_id("rladies/secret-plans", "_meta", 0L))
  })

  it("returns each id once", {
    local_mocked_bindings(gh_fetch_readme = function(...) purge_readme(2))
    ids <- rag_private_repo_ids(purge_repo(), "token")
    expect_identical(anyDuplicated(ids), 0L)
  })
})

describe("rag_purge_private", {
  local_purge <- function(repos, env = parent.frame()) {
    calls <- new.env(parent = emptyenv())
    calls$deleted <- character(0)
    calls$batches <- 0L
    withr::local_envvar(GITHUB_TOKEN = "token", .local_envir = env)
    local_mocked_bindings(
      gh = function(endpoint, ...) repos,
      .package = "gh",
      .env = env
    )
    local_mocked_bindings(
      gh_fetch_readme = function(...) NULL,
      cloudflare_vectorize_delete_by_ids = function(ids, ...) {
        calls$deleted <- c(calls$deleted, ids)
        calls$batches <- calls$batches + 1L
        list()
      },
      .env = env
    )
    calls
  }

  it("deletes the ids of every private repo", {
    calls <- local_purge(list(
      purge_repo("rladies/secret-plans"),
      purge_repo("rladies/also-secret")
    ))
    expect_message(n <- rag_purge_private("rladies", "acct", "tok", "idx"))
    expect_identical(n, 2L)
    expect_setequal(
      calls$deleted,
      c(
        rag_chunk_id("rladies/secret-plans", "_meta", 0L),
        rag_chunk_id("rladies/also-secret", "_meta", 0L)
      )
    )
  })

  it("leaves public repos alone", {
    calls <- local_purge(list(purge_repo("rladies/open", private = FALSE)))
    expect_message(n <- rag_purge_private("rladies", "acct", "tok", "idx"))
    expect_identical(n, 0L)
    expect_length(calls$deleted, 0)
  })

  it("batches large deletes", {
    many <- lapply(
      seq_len(1200),
      function(i) purge_repo(paste0("rladies/secret-", i))
    )
    calls <- local_purge(many)
    expect_message(rag_purge_private(
      "rladies",
      "a",
      "t",
      "i",
      batch_size = 500L
    ))
    expect_identical(calls$batches, 3L)
  })

  it("carries on when one repo's ids cannot be computed", {
    calls <- local_purge(list(
      purge_repo("rladies/secret-plans"),
      purge_repo("rladies/broken")
    ))
    local_mocked_bindings(
      gh_fetch_readme = function(full_name, ...) {
        if (grepl("broken", full_name)) {
          stop("api down")
        }
        NULL
      }
    )
    expect_message(n <- rag_purge_private("rladies", "a", "t", "i"))
    expect_identical(n, 1L)
  })

  it("does nothing without a GitHub token", {
    withr::local_envvar(GITHUB_TOKEN = "")
    expect_message(
      n <- rag_purge_private("rladies", "a", "t", "i"),
      "skipping private purge"
    )
    expect_identical(n, 0L)
  })
})
