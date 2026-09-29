# Read the metadata of local R package sources

Read the metadata of local R package sources

## Usage

``` r
local_r_package_info(paths)
```

## Arguments

- paths:

  Character vector. Paths to package source folders or `.tar.gz` /
  `.tgz` source tarballs.

## Value

A list with one element per path, named by package. Each element holds
`path`, `package`, `version`, `deps` (the package names from `Depends`,
`Imports` and `LinkingTo`, without `R`) and `is_dir`.
