# Resolve the declared dependencies of local R package paths

Reads `Depends`, `Imports` and `LinkingTo` from each local package's
`DESCRIPTION` (directories and archives alike) so the repository install
step can install them before the local package is installed from source.
Version constraints and `R` are stripped, and base/recommended packages
are dropped.

## Usage

``` r
local_r_package_deps(paths)
```

## Arguments

- paths:

  Character vector. Paths to local package directories or archives.

## Value

Character vector of dependency package names.
