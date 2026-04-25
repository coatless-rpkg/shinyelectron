# Resolve the app type for a multi-app entry

Reads per-app `type`, falls back to suite-level `build.type`, and routes
legacy values through
[`normalize_app_type_arg()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/normalize_app_type_arg.md)
so the caller always sees canonical `"r-shiny"` / `"py-shiny"`. A legacy
per-app type is treated as a self-contained shinylive declaration and
does not mix with the suite-level `runtime_strategy`, since the two
could otherwise conflict (e.g. a legacy `"r-shinylive"` entry inside a
suite whose default strategy is `"system"`).

## Usage

``` r
resolve_app_type(app, config)
```

## Arguments

- app:

  List. Single app entry from config\$apps.

- config:

  List. Full configuration.

## Value

Character string. The resolved canonical app type.
