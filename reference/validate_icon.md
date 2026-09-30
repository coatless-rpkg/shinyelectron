# Validate icon file for target platform

Checks that the icon file exists and that each target platform can use
it, for its format and for the size of its image (see
[`icon_platforms()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/icon_platforms.md)).
A platform that cannot gets the default Electron icon, so this warns
rather than errors and the build continues.

## Usage

``` r
validate_icon(icon, platform = NULL)
```

## Arguments

- icon:

  Character path to icon file.

- platform:

  Character vector of target platforms.
