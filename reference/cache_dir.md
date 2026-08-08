# Get or create cache directory path

Determines the path to the cache directory for shinyelectron assets and
optionally creates the directory if it doesn't exist.

## Usage

``` r
cache_dir(create = TRUE)
```

## Arguments

- create:

  Logical. Whether to create the directory if it doesn't exist. Default
  is TRUE.

## Value

Character string. The absolute path to the cache directory.

## Details

The cache directory is located at
`rappdirs::user_cache_dir("shinyelectron")/assets`. This function
centralizes path management for all cached assets used by the package.

## Cache Structure

The cache directory structure (typically at
~/.shinyelectron/cache/assets/):


    assets/
    |-- r/
    |   |-- win/
    |   |   |-- x64/
    |   |   |-- arm64/
    |   |-- mac/
    |   |   |-- x64/
    |   |   |-- arm64/
    |   |-- linux/
    |       |-- x64/
    |       |-- arm64/
    |-- npm/
