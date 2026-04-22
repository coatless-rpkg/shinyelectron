# Clear the asset cache

Removes cached R installations and/or npm packages from the cache
directory.

## Usage

``` r
cache_clear(what = c("all", "r", "npm", "nodejs", "python"))
```

## Arguments

- what:

  Character string specifying what to clear. One of `"all"`, `"nodejs"`,
  `"r"`, `"python"`, or a specific cache subdirectory name.

## Value

Invisibly returns NULL.

## Details

Use this function to free disk space or force re-downloading of assets:

- `"r"`: Removes only cached R installations

- `"npm"`: Removes only cached npm packages

- `"nodejs"`: Removes only cached Node.js installations

- `"python"`: Removes only cached Python installations

- `"all"`: Removes all cached assets

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

# Clear only Node.js installations
cache_clear("nodejs")

# Clear only Python installations
cache_clear("python")
} # }
```
