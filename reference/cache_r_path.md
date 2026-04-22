# Get path to cached R installation

Creates the path to a specific R installation in the cache based on
version, platform, and architecture.

## Usage

``` r
cache_r_path(version, platform, arch)
```

## Arguments

- version:

  Character string. R version (e.g., "4.1.0").

- platform:

  Character string. Target platform ("win", "mac", or "linux").

- arch:

  Character string. Target architecture ("x64" or "arm64").

## Value

Character string. The path to the cached R installation for the
specified version, platform, and architecture.

## Details

The path is structured as `cache_dir()/r/[platform]/[arch]/[version]`.
This function does not check if the installation exists at that
location.
