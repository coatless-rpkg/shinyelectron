# Report the app's display name and slug

Prints the display name with the slug in
[`export()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/export.md)'s
progress output. When the slug came from the folder rather than from
`app.slug` and differs from the slug the display name would give, it
also says how to choose another and what changing it means for installed
copies.

## Usage

``` r
alert_app_identity(label, app_name, slug, pinned)
```

## Arguments

- label:

  Character. What the name belongs to, such as `"Application"`.

- app_name:

  Character. The display name.

- slug:

  Character or `NULL`. The slug.

- pinned:

  Logical. Whether the configuration sets `app.slug`.

## Value

Called for its messages.
