# Read the metadata of local R package sources

Reads the `DESCRIPTION` of each source folder, or the one in a source
tarball's top-level folder.
[`resolve_local_packages()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/resolve_local_packages.md)
calls this, and the later steps of an export take its result rather than
reading again.

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
