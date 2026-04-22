# Resolve application dependencies

Top-level function that detects, merges, and returns the final list of
package dependencies for an app. Called from export() for native app
types.

## Usage

``` r
resolve_app_dependencies(appdir, app_type, config)
```

## Arguments

- appdir:

  Character string. Path to the app directory.

- app_type:

  Character string. The app type.

- config:

  List. The effective configuration.

## Value

List with `packages`, `language`, and `repos`/`index_urls`, or NULL for
shinylive types (which don't need dependency management).
