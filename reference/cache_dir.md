# Get or create the cache directory path

Returns the path where shinyelectron stores downloaded runtimes (R,
Python, Node.js) and other cached assets. By default, the directory is
created if it doesn't already exist. Pass `create = FALSE` to query the
path without side effects.

## Usage

``` r
cache_dir(create = TRUE)
```

## Arguments

- create:

  Logical. Whether to create the directory if it doesn't exist. Default
  is TRUE.

## Value

Character string. Absolute path to the cache directory, typically
`~/.cache/shinyelectron/assets` on Linux,
`~/Library/Caches/shinyelectron/assets` on macOS, or
`\%LOCALAPPDATA\%/shinyelectron/shinyelectron/Cache/assets` on Windows.

## Cache Layout

Cached runtimes are organized by type, platform, architecture, and
version:

    assets/
    |-- r/
    |   |-- win/x64/4.5.3/
    |   |-- mac/arm64/4.5.3/
    |-- python/
    |   |-- win/x64/3.12.10/
    |   |-- mac/arm64/3.12.10/
    |-- nodejs/
    |   |-- v22.11.0/darwin-arm64/
    |   |-- v22.11.0/win-x64/

Use
[`cache_info()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/cache_info.md)
to see what's actually installed with disk usage.

## See also

[`cache_info()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/cache_info.md)
to see what's cached,
[`cache_clear()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/cache_clear.md)
to remove cached assets,
[`cache_remove()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/cache_remove.md)
to remove a specific version.

## Examples

``` r
# Query without creating
cache_dir(create = FALSE)
#> [1] "/home/runner/.cache/shinyelectron/assets"

# Get or create
cache_dir()
#> [1] "/home/runner/.cache/shinyelectron/assets"
```
