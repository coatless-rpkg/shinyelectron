# Declared dependencies of local R packages

The packages that each local package's `Depends`, `Imports` and
`LinkingTo` name (directories and archives alike), so the repository
install step can install them before the local package is installed from
source.
[`local_r_package_info()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/local_r_package_info.md)
has already stripped version constraints and `R`; base/recommended
packages are dropped here.

## Usage

``` r
local_r_package_deps(packages)
```

## Arguments

- packages:

  List. Local packages as
  [`resolve_local_packages()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/resolve_local_packages.md)
  or
  [`local_r_package_info()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/local_r_package_info.md)
  return them.

## Value

Character vector of dependency package names.
