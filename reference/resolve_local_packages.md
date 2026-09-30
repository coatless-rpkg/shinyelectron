# Resolve, check and read the configured local R package sources

Turns the `dependencies.r.local_packages` entries into absolute paths
and reads each package's `DESCRIPTION` before anything is copied or
downloaded.
[`export()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/export.md)
and the multi-app export call this with the directory that holds
`_shinyelectron.yml` (the app directory, or the suite root) and put the
result in the configuration, so the later steps of the export use what
was read here instead of reading each source again.
[`embed_r_runtime()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/embed_r_runtime.md)
calls it again for direct callers; a list that this function returned
comes back unchanged. Each entry must be a package source folder (with a
`DESCRIPTION`) or a `.tar.gz` / `.tgz` source tarball.

## Usage

``` r
resolve_local_packages(local_packages, base_dir, bundled_r = TRUE)
```

## Arguments

- local_packages:

  Character vector or list. The configured entries, or a list that this
  function returned.

- base_dir:

  Character. Directory that relative entries resolve against.

- bundled_r:

  Logical. Whether an R app in this build uses the bundled strategy.
  Local packages are only installed into a bundled R library, so a
  non-empty list aborts when this is `FALSE`.

## Value

The packages as
[`local_r_package_info()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/local_r_package_info.md)
reads them, with absolute paths, in a list of class
`shinyelectron_local_packages` (empty when nothing is set).
