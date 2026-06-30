# Valid demo build matrix

Enumerates every (demo, strategy, platform, arch) combination the demo
build workflow produces, after applying validity rules. The CI workflow
and the download tables in the README and the download-demos article all
read this, so the build matrix and the published links cannot drift.

## Usage

``` r
demo_release_matrix()
```

## Value

A data frame with one row per valid combination and columns `demo`,
`name`, `language`, `strategy`, `platform`, `arch`, `runner`,
`asset_name`, `requirement`.
