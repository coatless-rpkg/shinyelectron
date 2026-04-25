# Prepare native Shiny app files for packaging

Copies the app source into `destdir/shiny-app/`, detects package
dependencies, and writes runtime + dependency manifests that the
Electron backends will consume at launch time.

## Usage

``` r
prepare_native_app_files(
  appdir,
  destdir,
  app_type,
  runtime_strategy,
  platform,
  arch,
  config,
  verbose = TRUE
)
```

## Arguments

- appdir:

  Character. Source Shiny app directory.

- destdir:

  Character. Export destination.

- app_type:

  Character. `"r-shiny"` or `"py-shiny"`.

- runtime_strategy:

  Character. Resolved runtime strategy.

- platform, arch:

  Character. Target platform / architecture.

- config:

  List. Effective merged configuration.

- verbose:

  Logical.

## Value

List with elements `converted_app` (path) and `dependencies` (NULL or
the resolved dep info).
