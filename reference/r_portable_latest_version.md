# Get the latest R version available as a portable-r build

The bundled and auto-download strategies download R from the portable-r
release repos, which can lag behind the newest R release (so the latest
R from
[`r_latest_version()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/r_latest_version.md)
may have no portable build yet, yielding a 404). This returns the latest
version that actually exists for the target platform, falling back to
[`r_latest_version()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/r_latest_version.md)
if the release API cannot be reached.

## Usage

``` r
r_portable_latest_version(platform = NULL)
```

## Arguments

- platform:

  Character string. Target platform: "win", "mac", "linux".

## Value

Character string. The latest available portable-r version.
