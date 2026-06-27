# Fetch the latest published Electron version from the npm registry

Queries `https://registry.npmjs.org/electron/latest` and returns the
`version` field as a character string. Used when
`dependencies$electron$version` is set to `"latest"`.

## Usage

``` r
electron_latest_version()
```

## Value

Character version string (e.g. `"41.0.0"`).
