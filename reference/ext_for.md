# Installer extension for a platform

The shinyelectron electron-builder template targets `dmg` on macOS,
`nsis` (an `.exe`) on Windows, and `AppImage` on Linux.

## Usage

``` r
ext_for(platform)
```

## Arguments

- platform:

  Character vector of `"mac"`, `"win"`, or `"linux"`.

## Value

Character vector of file extensions.
