# Get path to npm packages cache

Determines the path to the cache directory for npm packages used by
shinyelectron.

## Usage

``` r
cache_npm_path()
```

## Value

Character string. The path to the npm packages cache.

## Details

The npm packages are cached at `cache_dir()/npm`. This allows for reuse
of downloaded npm dependencies across multiple builds.
