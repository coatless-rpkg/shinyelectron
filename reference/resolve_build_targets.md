# Resolve the platforms and architectures to build for

The `platform` and `arch` arguments of
[`export()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/export.md)
win over `build.platforms` and `build.architectures` in
`_shinyelectron.yml`, which win over the platform and architecture of
the build machine. Each argument replaces only its own list, and
repeated values are dropped. The result is checked as
[`build_electron_app()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/build_electron_app.md)
checks its arguments, so an invalid value stops the export before
anything is converted or built.

## Usage

``` r
resolve_build_targets(platform, arch, config)
```

## Arguments

- platform, arch:

  Character vectors or `NULL`. The arguments.

- config:

  List. The effective configuration.

## Value

A list with the character vectors `platform` and `arch`, and
`from_config`, the settings that supplied them (`"build.platforms"`,
`"build.architectures"`, both or neither), for error messages.
