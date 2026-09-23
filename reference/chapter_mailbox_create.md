# Create a chapter mailbox in Google Workspace

Asks the jinx worker to provision `<city>@rladies.org` in the
`/Chapters` organisational unit. The Workspace service account key lives
in the worker rather than in CI, so this call carries only the worker
API key: the most a stolen CI token can do is ask for a mailbox whose
name passes the worker's validation.

## Usage

``` r
chapter_mailbox_create(
  city,
  given_name = NULL,
  family_name = NULL,
  base_url = "https://jinx.rladies.org",
  api_key = Sys.getenv("JINX_API_KEY")
)
```

## Arguments

- city:

  Chapter city. The worker transliterates and validates it, and refuses
  reserved addresses.

- given_name:

  Given name on the account. Defaults to `"RLadies+"`.

- family_name:

  Family name on the account. Defaults to the city.

- base_url:

  Worker base URL.

- api_key:

  Worker API key. Defaults to the `JINX_API_KEY` environment variable.

## Value

The created address (invisibly).

## Details

The signing and Directory API calls could be done here in R - `openssl`
signs RS256 perfectly well - but that would require the service account
key on the Actions runner that runs this function, which is the thing
the current arrangement avoids. `worker/src/workspace.js` carries the
full reasoning; it is a deliberate exception to moving worker logic into
this package.

The generated password is never returned. The account is created with
change-password-at-next-login set, and the onboarding team issues the
handover from the Admin console.
