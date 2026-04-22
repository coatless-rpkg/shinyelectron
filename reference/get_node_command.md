# Get Node.js command

Returns the path to the Node.js executable, preferring locally installed
versions managed by shinyelectron.

## Usage

``` r
get_node_command(prefer_local = TRUE)
```

## Arguments

- prefer_local:

  Logical. Whether to prefer the local shinyelectron-managed
  installation over the system installation. Default TRUE.

## Value

Character string path to node executable
