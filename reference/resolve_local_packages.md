# Resolve and check the configured local R package sources

Turns the `dependencies.r.local_packages` entries into absolute paths
and checks them before anything is copied or downloaded.
[`export()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/export.md)
and the multi-app export call this with the directory that holds
`_shinyelectron.yml` (the app directory, or the suite root), and
[`embed_r_runtime()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/embed_r_runtime.md)
calls it again for direct callers. Each entry must be a package source
folder (with a `DESCRIPTION`) or a `.tar.gz` / `.tgz` source tarball.

## Usage

``` r
resolve_local_packages(local_packages, base_dir, bundled_r = TRUE)
```

## Arguments

- local_packages:

  Character vector or list. The configured entries.

- base_dir:

  Character. Directory that relative entries resolve against.

- bundled_r:

  Logical. Whether an R app in this build uses the bundled strategy.
  Local packages are only installed into a bundled R library, so a
  non-empty list aborts when this is `FALSE`.

## Value

Character vector of absolute paths (empty when nothing is set).
