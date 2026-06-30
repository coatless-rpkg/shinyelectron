# Fetch a published SHA-256 checksum for a portable runtime archive

Reads a checksum file published alongside a runtime release and returns
the hash for one archive. Two layouts are supported, both in the
standard `sha256sum` format (`<hash> <filename>`):

## Usage

``` r
fetch_published_sha256(checksum_url, asset_filename = NULL)
```

## Arguments

- checksum_url:

  Character. URL of the `.sha256` sidecar or `SHA256SUMS`.

- asset_filename:

  Character or NULL. Archive file name to match within a combined
  `SHA256SUMS`; `NULL` for a single-asset sidecar.

## Value

Character SHA-256 hash, or `NULL`.

## Details

- Per-asset sidecar (portable R): the checksum file contains a single
  line for the archive. Pass `asset_filename = NULL` and the first
  line's hash is returned.

- Combined `SHA256SUMS` (python-build-standalone): the file lists every
  asset. Pass `asset_filename` and the matching line's hash is returned.

Returns `NULL` when the checksum cannot be fetched or no matching entry
is found, so callers can continue without verification rather than
failing on a transient network error (the same graceful-skip behavior as
the Node.js installer).
