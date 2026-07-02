# Detect an app's package dependencies

Scans a Shiny app's source for the R or Python packages it uses, with
the same detection shinyelectron applies at build time. This is useful
before a shinylive build, in CI especially, because
[`shinylive::export()`](https://posit-dev.github.io/r-shinylive/reference/export.html)
compiles the WebAssembly bundle from the packages installed in the
current session, so an app's dependencies must be installed before
conversion.

## Usage

``` r
app_dependencies(appdir, app_type = NULL)
```

## Arguments

- appdir:

  Character string. Path to the app or multi-app suite directory.

- app_type:

  Character string or `NULL`. `"r-shiny"` or `"py-shiny"`, or `NULL` to
  autodetect from `appdir`.

## Value

Character vector of detected package names, excluding base R packages
(for R) or the Python standard library (for Python).

## Examples

``` r
if (FALSE) { # \dontrun{
# Install an app's R dependencies before a shinylive build
pkgs <- app_dependencies("path/to/app")
install.packages(pkgs)
} # }
```
