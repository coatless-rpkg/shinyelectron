# Normalize app_type and runtime_strategy arguments

Translates legacy app_type values (`r-shinylive`, `py-shinylive`) to the
canonical language pair (`r-shiny`, `py-shiny`) and backfills
`runtime_strategy = "shinylive"` when the caller has not set it. Emits a
deprecation warning of class `"shinyelectron_deprecated_app_type"` so
callers can muffle it and tests can match it precisely. Errors when a
legacy type is combined with an explicit non-shinylive strategy, since
that combination never worked under the old API.

## Usage

``` r
normalize_app_type_arg(app_type, runtime_strategy = NULL)
```

## Arguments

- app_type:

  Character string or NULL. Raw app_type from the user.

- runtime_strategy:

  Character string or NULL. Raw runtime_strategy.

## Value

List with elements `app_type` (canonical or NULL), `runtime_strategy`
(may still be NULL), and `deprecated` (logical).
