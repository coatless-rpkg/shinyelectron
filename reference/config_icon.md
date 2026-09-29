# Pick the app icon named in the configuration

The top-level `icon` wins over the per-platform `icons` entry, as in
[`export()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/export.md).

## Usage

``` r
config_icon(config, platform)
```

## Arguments

- config:

  List. The configuration.

- platform:

  Character. The target platform: `"mac"`, `"win"` or `"linux"`.

## Value

`NULL` when no icon is configured; otherwise a list with `field` (the
key, such as `"icons.mac"`) and `path`.
