# Detect R package dependencies from source files

Uses
[`renv::dependencies()`](https://rstudio.github.io/renv/reference/dependencies.html)
to scan R source files for package references. This catches
[`library()`](https://rdrr.io/r/base/library.html),
[`require()`](https://rdrr.io/r/base/library.html), `pkg::func()`,
[`loadNamespace()`](https://rdrr.io/r/base/ns-load.html), and other
patterns.

## Usage

``` r
detect_r_dependencies(appdir)
```

## Arguments

- appdir:

  Character string. Path to the app directory.

## Value

Character vector of unique package names (sorted), excluding base and
recommended R packages.
