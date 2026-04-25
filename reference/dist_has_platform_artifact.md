# Check whether electron-builder produced output for a platform

electron-builder 26.x has a known bug where the build completes and the
installer is written to disk, but the process then exits with status 1
during post-build publish metadata. When that happens, processx-invoked
npm inherits the non-zero exit even though the .dmg/.exe/.AppImage is
sitting right there. We treat "artifact exists" as success.

## Usage

``` r
dist_has_platform_artifact(output_dir, p)
```

## Arguments

- output_dir:

  Character Electron project directory

- p:

  Character platform identifier (`"mac"`, `"win"`, or `"linux"`)

## Value

Logical: `TRUE` if a platform-specific installer is present.
