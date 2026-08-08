# Clear the asset cache

Removes cached R installations and/or npm packages from the cache
directory.

## Usage

``` r
cache_clear(what = c("all", "r", "npm"))
```

## Arguments

- what:

  Character string. What to clear: "all" (default), "r", or "npm".

## Value

Invisibly returns NULL.

## Details

Use this function to free disk space or force re-downloading of assets:

- `"r"`: Removes only cached R installations

- `"npm"`: Removes only cached npm packages

- `"all"`: Removes both R installations and npm packages

If the cache directory doesn't exist, a message is shown and nothing is
done.

## Examples

``` r
if (FALSE) { # \dontrun{
# Clear everything in the cache
cache_clear()

# Clear only R installations
cache_clear("r")

# Clear only npm packages
cache_clear("npm")
} # }
```
