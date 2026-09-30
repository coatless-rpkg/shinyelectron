# Warn about the `icons` entries an export leaves out

One export copies one app icon and gives it to every target platform
that can use it: `icon`, or else the `icons` entry of the first target
platform (see
[`config_icon()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/config_icon.md)).
The `icons` entries of the other target platforms are then not used.

## Usage

``` r
check_unused_icons(config, platform)
```

## Arguments

- config:

  List. The configuration.

- platform:

  Character vector. The target platforms, the first one first.

## Value

Invisibly, the fields of the entries that are not used, such as
`"icons.win"`, or `character(0)`.
