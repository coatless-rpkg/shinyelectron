# Embed a portable R runtime into a bundled Electron build

Behavior-preserving extraction of the R bundled-embedding block from
[`build_electron_app()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/build_electron_app.md).
ALWAYS installs + copies the interpreter (and resolves symlinks) so the
shared `runtime/R` path exists for suite-wide bundled detection; only
the package install is gated on a non-empty `packages` set. `packages`
is the DIRECT set (as stored in `dependencies.json`); the recursive
dependency closure and the `pre_installed` setdiff are resolved here,
against the freshly-created `runtime/R/library`.

## Usage

``` r
embed_r_runtime(
  output_dir,
  packages,
  repos,
  version,
  platform,
  arch,
  verbose = TRUE
)
```

## Arguments

- output_dir:

  Character. The Electron app output directory.

- packages:

  Character vector. DIRECT R package names (may be empty/NULL).

- repos:

  Character vector. CRAN-like repository URLs.

- version:

  Character. Resolved R version (non-NULL from callers).

- platform:

  Character scalar. Target platform ("win"/"mac"/"linux").

- arch:

  Character scalar. Target architecture ("x64"/"arm64").

- verbose:

  Logical. Whether to display progress.

## Value

Invisibly, the path to the embedded `runtime/R` directory.
