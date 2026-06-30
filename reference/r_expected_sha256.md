# Published SHA-256 checksum for a portable R archive

Portable R publishes a per-asset `.sha256` sidecar next to each release
archive (`<archive-url>.sha256`). Returns `NULL` when unavailable so the
caller can continue without verification.

## Usage

``` r
r_expected_sha256(version, platform = NULL, arch = NULL)
```

## Arguments

- version:

  Character string. R version (e.g., "4.4.0").

- platform:

  Character string. Target platform: "win", "mac", "linux".

- arch:

  Character string. Target architecture: "x64", "arm64".

## Value

Character SHA-256 hash, or `NULL`.
