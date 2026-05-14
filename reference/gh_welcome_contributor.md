# Welcome a contributor on a new PR or issue

Checks if the PR/issue author has previous contributions to the repo. If
this is their first, posts a warm welcome message. If not, posts a
shorter thank-you. No-op for bots and global team members.

## Usage

``` r
gh_welcome_contributor(
  owner,
  repo,
  number,
  author,
  is_pr = TRUE,
  org = "rladies",
  extra_message = NULL
)
```

## Arguments

- owner:

  Repository owner.

- repo:

  Repository name.

- number:

  Issue or PR number.

- author:

  GitHub login of the author.

- is_pr:

  Whether this is a PR (TRUE) or issue (FALSE).

- org:

  Organization name.

- extra_message:

  Optional extra markdown to append after the standard welcome message
  (e.g. a project-specific reminder). Ignored when blank or `NULL`. The
  jinx signature is preserved as the final paragraph.

## Value

Comment URL or `NULL` if author is a team member (invisibly).
