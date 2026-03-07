# Auto-generate a blog entry JSON from a URL

Fetches OpenGraph metadata from the URL and creates a JSON entry
compatible with awesome-rladies-blogs format.

## Usage

``` r
create_blog_entry(url, language = "en", author_name, output_dir = ".")
```

## Arguments

- url:

  Blog URL.

- language:

  Language code. Defaults to `"en"`.

- author_name:

  Author name. Required.

- output_dir:

  Directory to write the JSON file. Defaults to `"."`.

## Value

File path of the created JSON (invisibly).
