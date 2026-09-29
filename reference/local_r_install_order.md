# Order local R packages so each installs after the local packages it needs

A stable topological sort over `Depends`, `Imports` and `LinkingTo`,
restricted to the local packages themselves. Packages keep their listed
order where their dependencies allow it.

## Usage

``` r
local_r_install_order(info)
```

## Arguments

- info:

  List from
  [`local_r_package_info()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/local_r_package_info.md).

## Value

Character vector of package names in install order.
