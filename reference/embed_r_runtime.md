# Embed a portable R runtime into a bundled Electron build

Behavior-preserving extraction of the R bundled-embedding block from
[`build_electron_app()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/build_electron_app.md).
ALWAYS installs + copies the interpreter (and resolves symlinks) so the
shared `runtime/R` path exists for suite-wide bundled detection; only
the package install is gated on a non-empty package set (`packages` plus
any local packages and their declared dependencies). `packages` is the
DIRECT set (as stored in `dependencies.json`); the recursive dependency
closure and the `pre_installed` setdiff are resolved here, against the
freshly-created `runtime/R/library`. Local packages are installed last,
with
[`install_local_r_packages()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/install_local_r_packages.md).

## Usage

``` r
embed_r_runtime(
  output_dir,
  packages,
  repos,
  version,
  platform,
  arch,
  verbose = TRUE,
  prune = TRUE,
  local_packages = character(0)
)
```

## Arguments

- output_dir:

  Character. The Electron app output directory.

- packages:

  Character vector. DIRECT R package names (may be empty/NULL).

- repos:

  Character vector. CRAN-like repository URLs. `NULL` uses the default
  CRAN mirror.

- version:

  Character. Resolved R version (non-NULL from callers).

- platform:

  Character scalar. Target platform ("win"/"mac"/"linux").

- arch:

  Character scalar. Target architecture ("x64"/"arm64").

- verbose:

  Logical. Whether to display progress.

- prune:

  Logical. Whether to remove the test and documentation files that
  [`prune_bundled_r_runtime()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/prune_bundled_r_runtime.md)
  allowlists once the packages are installed. Callers pass the validated
  `dependencies.r.prune` setting.

- local_packages:

  Local R packages to install into the bundled library after the
  repository packages: the list
  [`resolve_local_packages()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/resolve_local_packages.md)
  returned, which is used as it was read, or paths to package source
  folders or `.tar.gz` source tarballs, which are read here.
  [`export()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/export.md)
  passes the packages it read; relative paths resolve against the
  working directory.

## Value

Invisibly, the path to the embedded `runtime/R` directory.
