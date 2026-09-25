# The Meetup URL name for a chapter

`meetup.com/rladies-<city>`, hyphenated for multi-word cities and
transliterated the way the website filenames already are. This value and
the group name cannot be changed after the group is created, so getting
them right first time is the whole point of rendering them here rather
than having someone type them.

## Usage

``` r
chapter_meetup_urlname(city)
```

## Arguments

- city:

  Chapter city.

## Value

The urlname, without the meetup.com prefix.
