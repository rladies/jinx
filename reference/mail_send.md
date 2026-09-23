# Send an email as jinx

Sends plain text mail from `jinx@rladies.org`, cc'ing
`chapters@rladies.org` by default so the onboarding inbox keeps the
thread. jinx never sends *as* `chapters@`, which is why this needs only
a single account's `gmail.send` token rather than domain-wide
delegation.

## Usage

``` r
mail_send(
  to,
  subject,
  body,
  cc = "chapters@rladies.org",
  from = "jinx@rladies.org"
)
```

## Arguments

- to:

  Recipient address, or a vector of them.

- subject:

  Message subject.

- body:

  Plain text body.

- cc:

  Cc address. Defaults to `"chapters@rladies.org"`; pass `NULL` for
  none.

- from:

  Sender address. Defaults to `"jinx@rladies.org"`.

## Value

The sent message id (invisibly).
