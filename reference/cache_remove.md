# Remove a specific cached runtime version

Removes a single cached runtime version instead of clearing the entire
cache. Use
[`cache_info()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/cache_info.md)
to see what's available.

## Usage

``` r
cache_remove(runtime, version, platform = NULL, arch = NULL)
```

## Arguments

- runtime:

  Character string. One of `"r"`, `"python"`, or `"nodejs"`.

- version:

  Character string. Version to remove (e.g., `"4.5.3"`, `"3.12.10"`,
  `"v22.11.0"`).

- platform:

  Character string. Platform (e.g., `"win"`, `"mac"`, `"linux"`). For
  Node.js, use the combined platform-arch format shown by
  [`cache_info()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/cache_info.md).

- arch:

  Character string. Architecture (`"x64"` or `"arm64"`). Ignored for
  Node.js (embedded in platform).

## Value

Invisibly returns TRUE if removed, FALSE if not found.

## See also

[`cache_info()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/cache_info.md)
to list cached versions,
[`cache_clear()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/cache_clear.md)
to remove all cached assets of a type.

## Examples

``` r
if (FALSE) { # \dontrun{
# Remove a specific R version
cache_remove("r", "4.4.0", "mac", "arm64")

# Remove a cached Python version
cache_remove("python", "3.12.10", "win", "x64")
} # }
```
