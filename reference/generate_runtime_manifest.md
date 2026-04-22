# Generate a runtime manifest for auto-download

Creates a JSON manifest that the Electron app reads on first launch to
download the R runtime.

## Usage

``` r
generate_runtime_manifest(version, platform = NULL, arch = NULL)
```

## Arguments

- version:

  Character string. R version.

- platform:

  Character string. Target platform.

- arch:

  Character string. Target architecture.

## Value

Character string. JSON content.
