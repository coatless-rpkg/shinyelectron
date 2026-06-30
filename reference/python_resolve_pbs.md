# Resolve a Python version to its python-build-standalone release

Scans release asset names of the form
`cpython-<ver>+<release>-<arch>-<os>-install_only.tar.gz`. For an
explicit version, returns the newest release that contains an asset for
that version. For `"latest"`, returns the first CPython version found in
the newest release.

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

## Details

Resolution tries the lightweight `releases/latest` endpoint first via
[`pbs_latest_release()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/pbs_latest_release.md),
which carries the newest patch of every supported minor and resolves the
common case in one reliable call. It falls back to the full release
history
([`pbs_list_releases()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/pbs_list_releases.md),
which can time out) only when the latest release does not contain the
requested version. Network access is isolated to those two helpers so
tests can stub them.
