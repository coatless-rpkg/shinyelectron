# Stop when a macOS target is built on another system

electron-builder makes macOS apps and their disk images only on macOS.
Elsewhere a `mac` build fails, and
[`build_for_platforms()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/build_for_platforms.md)
only reports the failure, so
[`export()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/export.md)
would finish without an installer. It calls this before anything is
converted instead.

## Usage

``` r
check_build_host(platform, from_config = character(0))
```

## Arguments

- platform:

  Character vector. The resolved target platforms.

- from_config:

  Character vector. The settings that supplied the targets, from
  [`resolve_build_targets()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/resolve_build_targets.md).

## Value

Invisibly `TRUE`. Stops with an error of class `shinyelectron_mac_host`
when a target is `mac` and the build machine is not.
