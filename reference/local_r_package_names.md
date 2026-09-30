# Package names of local R packages

Package names of local R packages

## Usage

``` r
local_r_package_names(packages)
```

## Arguments

- packages:

  List. Local packages as
  [`resolve_local_packages()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/resolve_local_packages.md)
  or
  [`local_r_package_info()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/local_r_package_info.md)
  return them.

## Value

Character vector of package names (empty when `packages` is empty).
