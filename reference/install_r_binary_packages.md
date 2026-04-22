# Install R packages as binary only

Installs R packages into a specified library path using only binary
packages. Aborts if a binary is not available rather than falling back
to source compilation.

## Usage

``` r
install_r_binary_packages(
  packages,
  lib_path,
  repos = c("https://cloud.r-project.org"),
  available_pkgs = NULL,
  verbose = TRUE
)
```

## Arguments

- packages:

  Character vector of package names.

- lib_path:

  Character string. Target library directory.

- repos:

  Character vector of repository URLs.

- available_pkgs:

  Optional matrix from
  [`utils::available.packages()`](https://rdrr.io/r/utils/available.packages.html).
  When supplied the CRAN lookup is skipped, avoiding a redundant network
  call during the same export session.

- verbose:

  Logical. Whether to show progress.
