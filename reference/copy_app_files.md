# Copy application files to Electron project

Copy application files to Electron project

## Usage

``` r
copy_app_files(
  app_dir,
  output_dir,
  app_type,
  runtime_strategy = NULL,
  verbose = TRUE
)
```

## Arguments

- app_dir:

  Character source app directory

- output_dir:

  Character destination directory

- app_type:

  Character application type

- runtime_strategy:

  Character resolved runtime strategy. When `"shinylive"` the source is
  already a WebAssembly bundle, so the Shiny entrypoint sanity check is
  skipped.

- verbose:

  Logical whether to show progress
