# Resolve a path written in the configuration file

Paths in `_shinyelectron.yml` are relative to the directory that holds
the file: the app directory, or the suite root of a multi-app suite. `~`
is expanded, and an absolute path is kept as it is.

## Usage

``` r
resolve_config_path(path, base_dir)
```

## Arguments

- path:

  Character. A path as written in the configuration.

- base_dir:

  Character. The directory that holds `_shinyelectron.yml`.

## Value

Character. The absolute path.
