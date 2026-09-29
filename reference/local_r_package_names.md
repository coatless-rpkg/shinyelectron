# Resolve the package names of local R package paths

Reads the `Package` field from each source folder's `DESCRIPTION`, or
from the `DESCRIPTION` in a source tarball's top-level folder.

## Usage

``` r
local_r_package_names(paths)
```

## Arguments

- paths:

  Character vector. Paths to local package directories or archives.

## Value

Character vector of package names (empty when `paths` is empty).
