# Lock in (or clear) the chosen slot for a poll

Host-only: requires the poll's `edit_token`.

## Usage

``` r
meeting_poll_lock(id, slot, edit_token, base_url = samkoma_base_url())
```

## Arguments

- id:

  Poll id.

- slot:

  The chosen slot identifier (`YYYY-MM-DDTHH:MM` or `[mon-sun]THH:MM`),
  or `NULL` to clear a previously locked slot.

- edit_token:

  Optional host edit token, required to read a hidden poll's responses.

- base_url:

  API base URL.

## Value

Invisibly, the parsed response.
