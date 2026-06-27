# Copy the Dockerfile for the container strategy and bake in app dependencies

Copy the Dockerfile for the container strategy and bake in app
dependencies

## Usage

``` r
copy_and_bake_dockerfiles(output_dir, app_type, config = NULL, verbose = TRUE)
```

## Arguments

- output_dir:

  Character. Destination build directory.

- app_type:

  Character. Application type (e.g. `"r-shiny"`, `"py-shiny"`).

- config:

  List of configuration values from the config file, or NULL. Used to
  resolve the runtime version that is baked into the `ARG` default line
  of the copied Dockerfile.

- verbose:

  Logical. Whether to show progress messages.
