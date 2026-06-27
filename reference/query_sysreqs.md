# Query Linux system package names for a set of R packages

Resolves the distribution system packages required by `pkgs` and their
recursive dependencies using the Posit Package Manager
system-requirements service. Returns `character(0)` on any failure so
callers degrade gracefully (a user can still name packages via
`dependencies.system_packages`).

## Usage

``` r
query_sysreqs(pkgs, distribution = "ubuntu", release = "24.04")
```

## Arguments

- pkgs:

  Character vector of R package names.

- distribution:

  Linux distribution, e.g. `"ubuntu"` or `"redhat"`.

- release:

  Distribution release, e.g. `"24.04"` or `"9"`.

## Value

Character vector of system package names (sorted, de-duplicated).

## Details

Queried over HTTP directly rather than through
[`pak::pkg_sysreqs()`](https://pak.r-lib.org/reference/pkg_sysreqs.html),
whose resolver returns an empty mapping in common configurations even
when the underlying data is available.
