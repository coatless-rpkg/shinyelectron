# Append app-specific package installs to the Dockerfile

Bakes system dependencies (via the Posit Package Manager sysreqs API and
`config$dependencies$system_packages`) and R/Python package installs
into the image at build time so container launch does not have to
compile/install packages on the user's machine.

## Usage

``` r
bake_dockerfile_dependencies(output_dir, dockerfile_dest, config = NULL)
```

## Details

For R apps the base image is `rocker/r-ver`, which pre-wires P3M
binaries; packages are therefore installed via
[`install.packages()`](https://rdrr.io/r/utils/install.packages.html).
