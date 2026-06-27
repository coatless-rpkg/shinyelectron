# Resolve a Python version to its python-build-standalone release

Scans release asset names of the form
`cpython-<ver>+<release>-<arch>-<os>-install_only.tar.gz`. For an
explicit version, returns the newest release that contains an asset for
that version. For `"latest"`, returns the newest release and the first
CPython version found in it. Network access is isolated to
[`pbs_list_releases()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/pbs_list_releases.md)
so tests can stub that function.

## Usage

``` r
python_resolve_pbs(version = "latest")
```

## Arguments

- version:

  Character string. A concrete Python version such as `"3.14.6"`, or
  `"latest"` for the newest available build.

## Value

Named list with elements `version` (character) and `release` (character
YYYYMMDD tag).
