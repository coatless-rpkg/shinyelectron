# Export multi-app Shiny suite as Electron application

[`export()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/export.md)
settles the suite's slug before it calls this function. When called
directly without `app.slug`, the slug comes from the resolved suite
name, as it did in earlier releases.

## Usage

``` r
export_multi_app(
  appdir,
  destdir,
  config,
  app_name = NULL,
  runtime_strategy = NULL,
  sign = FALSE,
  platform = NULL,
  arch = NULL,
  icon = NULL,
  overwrite = FALSE,
  build = TRUE,
  run_after = FALSE,
  open_after = FALSE,
  verbose = TRUE,
  slug_pinned = !is.null(config$app$slug)
)
```

## Arguments

- slug_pinned:

  Logical. Whether the configuration sets `app.slug`, for the progress
  output;
  [`export()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/export.md)
  passes it because it fills in the slug before the call.
