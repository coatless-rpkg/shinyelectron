# Resolve the `dependencies.r.prune` setting

Returns whether a bundled R runtime is pruned: the configured value, or
`TRUE` when it is unset. A quoted `"true"` or `"false"` is read as the
matching logical with a warning, and any other value aborts (see
[`config_flag()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/config_flag.md)),
so a typo never silently decides which files ship.

## Usage

``` r
resolve_r_prune(config)
```

## Arguments

- config:

  List. Configuration, as from
  [`read_config()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/read_config.md).
  May be `NULL`.

## Value

`TRUE` or `FALSE`.
