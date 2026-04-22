# Install Node.js locally

Downloads and installs Node.js to the shinyelectron cache directory.
This allows using Node.js/npm without requiring system-wide
installation.

## Usage

``` r
install_nodejs(
  version = NULL,
  platform = NULL,
  arch = NULL,
  force = FALSE,
  verbose = TRUE
)
```

## Arguments

- version:

  Character Node.js version to install. If NULL (default), automatically
  detects the latest LTS version.

- platform:

  Character target platform ("win", "mac", "linux"). Default is current
  platform.

- arch:

  Character target architecture ("x64", "arm64"). Default is current
  architecture.

- force:

  Logical whether to reinstall if already exists. Default FALSE.

- verbose:

  Logical whether to show progress. Default TRUE.

## Value

Invisibly returns the path to the installed Node.js directory.

## See also

[`install_r()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/install_r.md),
[`install_python()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/install_python.md)
for other runtime installers.

## Examples

``` r
if (FALSE) { # \dontrun{
# Install latest LTS version
install_nodejs()

# Install specific version
install_nodejs(version = "20.0.0")

# Force reinstall
install_nodejs(force = TRUE)
} # }
```
