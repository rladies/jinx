# Create a new chapter JSON file

Generates a chapter JSON entry for the website.

## Usage

``` r
create_chapter(
  city,
  country,
  organizers,
  social_media = list(),
  status = "prospective",
  output_dir = "."
)
```

## Arguments

- city:

  City name.

- country:

  Country name.

- organizers:

  Character vector of organizer names.

- social_media:

  Named list of social media links (e.g.
  `list(meetup = "...", email = "city@rladies.org")`).

- status:

  Chapter status. Defaults to `"prospective"`.

- output_dir:

  Directory to write the JSON file.

## Value

File path of the created JSON (invisibly).
