# Resolve application dependencies

Top-level function that detects, merges, and returns the final list of
package dependencies for an app. Called from export() for native app
types.

## Usage

``` r
resolve_app_dependencies(appdir, app_type, runtime_strategy, config)
```

## Arguments

- appdir:

  Character string. Path to the app directory.

- app_type:

  Character string. The app type (`"r-shiny"` or `"py-shiny"`).

- runtime_strategy:

  Character string. The resolved runtime strategy. Returns NULL when
  `"shinylive"`, since shinylive manages its own deps.

- config:

  List. The effective configuration.

## Value

List with `packages`, `language`, and `repos`/`index_urls`, or NULL for
the shinylive strategy.
