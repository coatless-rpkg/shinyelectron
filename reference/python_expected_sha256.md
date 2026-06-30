# Published SHA-256 checksum for a portable Python archive

python-build-standalone publishes one `SHA256SUMS` file per release
listing every asset. Returns `NULL` when unavailable or unmatched so the
caller can continue without verification.

## Usage

``` r
python_expected_sha256(version, platform = NULL, arch = NULL, release_date)
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

Character SHA-256 hash, or `NULL`.
