# Install local R package sources into the bundled library

Installs each local package with the cached portable `Rscript` that also
installs the repository packages, one package at a time and after the
local packages it depends on
([`local_r_install_order()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/local_r_install_order.md)).
A source folder is first built into a tarball in a temporary directory
with the same portable R's `R CMD build`, so nothing is compiled or
written inside the folder and stale object files in it never reach the
bundle. The build waits until the repository packages and the earlier
local packages are in the library, because `R CMD build` installs the
package to process help pages with build-stage Sexpr macros, and that
install needs the package's dependencies.

## Usage

``` r
install_local_r_packages(
  rscript,
  local_packages,
  lib_path,
  verbose = TRUE,
  timeout = 1800
)
```

## Arguments

- rscript:

  Character. Path to the cached portable `Rscript`.

- local_packages:

  List. The local packages as
  [`resolve_local_packages()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/resolve_local_packages.md)
  or
  [`local_r_package_info()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/local_r_package_info.md)
  read them from their source folders or source tarballs.

- lib_path:

  Character. Destination library (the bundled library).

- verbose:

  Logical. Whether to display progress.

- timeout:

  Numeric. Seconds allowed for building or installing one package. The
  default of 30 minutes leaves room for large packages with compiled
  code.

## Value

Invisibly, the installed package names in install order.

## Details

A package counts as installed only when a fresh process of the same
`Rscript` loads it from the bundled library. That check catches compile
errors, `.onLoad()` failures and timed-out installs, and because it
looks for a line printed after loading rather than at the exit status,
it also tolerates the Windows crash described below. On failure the
build stops with the load error and the last lines of the install
output.

The build, the install and the check run with the caller's environment
plus `R_LIBS`, `R_LIBS_USER` and `R_LIBS_SITE` set to the bundled
library. `R_LIBS_SITE` is the one that matters: the portable R's
`Rprofile.site` resets
[`.libPaths()`](https://rdrr.io/r/base/libPaths.html) to its own library
plus the site library, including in the child processes of `R CMD build`
and `R CMD INSTALL`. These processes read no user environ file or user
profile and ignore inherited `R_ENVIRON` and `R_PROFILE` settings, so
startup files meant for the calling R (such as the ones callr passes
down, or a project profile that activates renv) cannot point the library
paths elsewhere; each R still reads its own site files.

On Windows hosts the install adds
`--no-staged-install --no-clean-on-error`. There the bundled R's
lazy-load step can crash while exiting, after it has written the
package, and `R CMD INSTALL` then reports a failure. These options keep
the files in place so the load check can decide. Elsewhere the default
staged install keeps a failed package out of the library.
