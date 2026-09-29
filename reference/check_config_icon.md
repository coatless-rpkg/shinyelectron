# Check the app icon named in the configuration

A configured icon that does not exist stops the export, as a missing
`icon` argument does in
[`validate_icon()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/validate_icon.md):
a build that quietly fell back to the default Electron icon would be
easy to ship by mistake.

## Usage

``` r
check_config_icon(config, platform, base_dir, call = parent.frame())
```

## Arguments

- config:

  List. The configuration.

- platform:

  Character. The target platform: `"mac"`, `"win"` or `"linux"`.

- base_dir:

  Character. The directory relative paths in `_shinyelectron.yml` were
  resolved against, named in the error.

- call:

  Environment. The function the error is reported from.

## Value

The icon path, or `NULL` when no icon is configured.
