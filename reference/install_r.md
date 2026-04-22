# Install a portable R distribution

Downloads and caches a portable R build. Follows the same pattern as
[`install_nodejs()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/install_nodejs.md).

## Usage

``` r
install_r(
  version = NULL,
  platform = NULL,
  arch = NULL,
  force = FALSE,
  verbose = TRUE
)
```

## Arguments

- version:

  Character string. R version to install. If NULL, installs latest.

- platform:

  Character string. Target platform.

- arch:

  Character string. Target architecture.

- force:

  Logical. Whether to reinstall if already cached.

- verbose:

  Logical. Whether to show progress.

## Value

Character string. Path to the installed R directory.

## See also

[`install_python()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/install_python.md),
[`install_nodejs()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/install_nodejs.md)
for other runtime installers;
[`r_executable()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/r_executable.md)
to find the installed Rscript path.

## Examples

``` r
if (FALSE) { # \dontrun{
# Install latest R release
install_r()

# Install specific version for a target platform
install_r(version = "4.4.0", platform = "win", arch = "x64")
} # }
```
