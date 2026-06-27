# Generate a Python runtime manifest for auto-download

Generate a Python runtime manifest for auto-download

## Usage

``` r
generate_python_runtime_manifest(
  version,
  platform = NULL,
  arch = NULL,
  release_date = NULL
)
```

## Arguments

- version:

  Character string. Python version.

- platform:

  Character string. Target platform.

- arch:

  Character string. Target architecture.

- release_date:

  Character string. python-build-standalone release tag (YYYYMMDD). If
  NULL, resolved automatically via
  [`resolve_python_pbs()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/resolve_python_pbs.md).

## Value

Character string. JSON content.
