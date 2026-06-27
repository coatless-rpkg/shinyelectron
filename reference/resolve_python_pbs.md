# Resolve a Python version to its python-build-standalone release (offline-first)

Uses the offline default pin when the version matches it (no network),
and only queries the registry for a custom or "latest" version.

## Usage

``` r
resolve_python_pbs(version)
```

## Arguments

- version:

  Character string. A concrete Python version such as `"3.14.6"`, or
  `"latest"` for the newest available build.

## Value

Named list with elements `version` (character) and `release` (character
YYYYMMDD tag).
