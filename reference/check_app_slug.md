# Check the app slug before a build starts

The build uses the slug only when it assembles the Electron app, after
the conversion and any runtime download. Checking it right after
[`resolve_app_slug()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/resolve_app_slug.md)
reports an invalid `app.slug`, or a name and directory that give no
slug, before that work.

## Usage

``` r
check_app_slug(slug)
```

## Arguments

- slug:

  The resolved slug, or `NULL` when none could be derived.

## Value

Invisible `TRUE`; aborts otherwise.
