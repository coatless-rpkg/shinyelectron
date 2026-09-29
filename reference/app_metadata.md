# Collect the app metadata settings

Reads `app.description`, `app.author`, `app.homepage`, and
`app.copyright` for `package.json` and the About dialog, keeping only
usable values: text is reduced to one line with
[`metadata_text()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/metadata_text.md),
so blank text counts as unset, the author is normalized with
[`normalize_app_author()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/normalize_app_author.md),
and a homepage must be an http or https URL
([`validate_config()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/validate_config.md)
rejects any other homepage).

## Usage

``` r
app_metadata(config)
```

## Arguments

- config:

  List. The effective configuration.

## Value

A list with `description`, `author`, `homepage`, and `copyright`
entries, each `NULL` when unset.
