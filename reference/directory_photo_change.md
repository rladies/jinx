# Resolve a photo download into a file change plus the entry `photo` block.

On download failure the entry `photo` is kept only if the image already
exists in the repo, so a failed fetch never leaves a dangling
`photo.url`.

## Usage

``` r
directory_photo_change(entry, org, repo, ref)
```
