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

  Character string. Version to remove (e.g., `"4.5.3"`, `"3.14.6"`,
  `"v22.11.0"`).

- platform:

  Character string. Platform (`"win"`, `"mac"`, or `"linux"`). Required
  for all runtimes including Node.js. Use the same canonical names that
  [`cache_info()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/cache_info.md)
  reports in the `platform` column (e.g. `"mac"`, not `"darwin"`).

- arch:

  Character string. Architecture (`"x64"` or `"arm64"`). Required for
  all runtimes including Node.js.

## Value

Invisibly returns TRUE if removed, FALSE if not found.

## See also

[`cache_info()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/cache_info.md)
to list cached versions,
[`cache_clear()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/cache_clear.md)
to remove all cached assets of a type.

## Examples

``` r
if (FALSE) { # interactive()
# Remove a specific R version
cache_remove("r", "4.4.0", "mac", "arm64")

# Remove a cached Python version
cache_remove("python", "3.14.6", "win", "x64")

# Remove one platform/arch slot of a Node.js version
cache_remove("nodejs", "v22.11.0", "mac", "arm64")
}
```
