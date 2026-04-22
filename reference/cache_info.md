# Show cached runtime information

Lists all cached runtimes (R, Python, Node.js) with their versions,
platforms, architectures, and disk usage. Modeled after
[`shinylive::assets_info()`](https://posit-dev.github.io/r-shinylive/reference/assets.html).

## Usage

``` r
cache_info(quiet = FALSE)
```

## Arguments

- quiet:

  Logical. If TRUE, suppresses console output and returns the results
  invisibly. Default is FALSE.

## Value

A data frame (returned invisibly) with columns: `runtime` (character),
`version` (character), `platform` (character), `arch` (character),
`size` (character, human-readable), and `path` (character).

## See also

[`cache_clear()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/cache_clear.md)
to remove cached assets,
[`cache_dir()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/cache_dir.md)
for the cache location.

## Examples

``` r
# Programmatic access (safe to run — just inspects the cache dir)
df <- cache_info(quiet = TRUE)
nrow(df)  # number of cached runtimes
#> [1] 0

if (FALSE) { # \dontrun{
# Pretty-print the cache contents
cache_info()
} # }
```
