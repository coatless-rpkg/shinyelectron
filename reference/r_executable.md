# Get the path to the Rscript executable in a cached installation

Get the path to the Rscript executable in a cached installation

## Usage

``` r
r_executable(version, platform = NULL, arch = NULL)
```

## Arguments

- version:

  Character string. R version.

- platform:

  Character string. Platform (default: current).

- arch:

  Character string. Architecture (default: current).

## Value

Character string or NULL. Path to Rscript, or NULL if not found.
