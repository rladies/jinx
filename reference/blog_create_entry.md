# Auto-generate a blog entry JSON file from a URL

Fetches OpenGraph metadata from the URL and writes a JSON entry
compatible with awesome-rladies-creations format.

## Usage

``` r
blog_create_entry(url, language = "en", author_name, output_dir = ".")
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
