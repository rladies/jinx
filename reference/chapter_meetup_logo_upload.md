# Set a chapter's Meetup group photo to the RLadies+ logo

Meetup uploads in two steps: a mutation registers the photo and returns
a signed `uploadUrl`, then the bytes are sent to that URL. The mutation
is named for event photos, but `photoType` carries a `GROUP_PHOTO` value
and `setAsMain` makes it the group's image.

## Usage

``` r
chapter_meetup_logo_upload(urlname, image = chapter_meetup_logo_path())
```

## Arguments

- urlname:

  Meetup group urlname.

- image:

  Path to the image. Defaults to the bundled RLadies+ profile logo.

## Value

The uploaded image path reported by Meetup (invisibly).
