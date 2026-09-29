# Validate configuration values

Checks configuration values and warns about invalid entries. The Windows
installer flags are read with
[`config_flag()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/config_flag.md):
a quoted `"true"` or `"false"` is used with a warning, but any other
invalid value aborts, as does
`installer.allow_to_change_installation_directory: true` without
`installer.one_click: false`, because falling back to a default would
build a different installer than the one requested.

## Usage

``` r
validate_config(config)
```

## Arguments

- config:

  List of configuration values

## Value

List of validated configuration
