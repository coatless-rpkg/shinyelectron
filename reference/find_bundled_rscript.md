# Locate Rscript inside a bundled portable-R runtime directory

The portable-r distribution extracts to a subdirectory named
`portable-r-<version>-<os>-<arch>/`. Rscript lives at
`<subdir>/bin/Rscript[.exe]`. Searches for that layout first, then falls
back to a flat layout in case a future portable build drops the subdir.

## Usage

``` r
find_bundled_rscript(runtime_dir)
```

## Arguments

- runtime_dir:

  Character path to `runtime/R` inside the Electron app.

## Value

Character path to Rscript, or NULL if not found.
