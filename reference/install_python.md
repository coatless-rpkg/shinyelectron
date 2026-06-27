# Install a portable Python distribution

Downloads and caches a portable Python build from
python-build-standalone.

## Usage

``` r
install_python(
  version = NULL,
  platform = NULL,
  arch = NULL,
  force = FALSE,
  verbose = TRUE
)
```

## Arguments

- version:

  Character string. Python version to install (e.g., `"3.14.6"`). If
  NULL, the maintained pin in
  `SHINYELECTRON_DEFAULTS$runtime_versions$python$version` is used.

- platform:

  Character string. Target platform.

- arch:

  Character string. Target architecture.

- force:

  Logical. Whether to reinstall if already cached.

- verbose:

  Logical. Whether to show progress.

## Value

Character string. Path to the installed Python directory.

## See also

[`install_r()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/install_r.md),
[`install_nodejs()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/install_nodejs.md)
for other runtime installers;
[`python_executable()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/python_executable.md)
to find the installed Python path.

## Examples

``` r
if (FALSE) { # \dontrun{
# Install default Python version
install_python()

# Install specific version
install_python(version = "3.12.0")
} # }
```
