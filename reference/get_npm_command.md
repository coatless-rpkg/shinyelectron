# Get npm command

Returns the path to the npm executable, preferring locally installed
versions managed by shinyelectron.

## Usage

``` r
get_npm_command(prefer_local = TRUE)
```

## Arguments

- prefer_local:

  Logical. Whether to prefer the local shinyelectron-managed
  installation over the system installation. Default TRUE.

## Value

Character string path to npm executable
