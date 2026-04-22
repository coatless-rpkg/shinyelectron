# Construct download URL for portable R

Generates the download URL for an R build from CRAN.

## Usage

``` r
r_download_url(version, platform = NULL, arch = NULL)
```

## Arguments

- version:

  Character string. R version (e.g., "4.4.0").

- platform:

  Character string. Target platform: "win", "mac", "linux".

- arch:

  Character string. Target architecture: "x64", "arm64".

## Value

Character string. Download URL.
