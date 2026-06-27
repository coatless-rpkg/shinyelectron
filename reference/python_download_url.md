# Construct download URL for portable Python

Uses python-build-standalone releases for portable Python builds.

## Usage

``` r
python_download_url(version, platform = NULL, arch = NULL, release_date)
```

## Arguments

- version:

  Character string. Python version (e.g., "3.14.6").

- platform:

  Character string. Target platform.

- arch:

  Character string. Target architecture.

- release_date:

  Character string. python-build-standalone release tag (YYYYMMDD).
  Required; must match a release tag on
  <https://github.com/astral-sh/python-build-standalone/releases>.

## Value

Character string. Download URL.
