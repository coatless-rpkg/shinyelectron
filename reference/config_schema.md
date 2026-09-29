# Configuration keys accepted in \_shinyelectron.yml

The keys of
[`default_config()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/default_config.md)
plus the top-level keys that have no default: the `icon` shortcut, the
multi-app `apps` list and the `logging` section that
[`map_logging_config()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/map_logging_config.md)
maps onto `app.log_dir` and `app.log_level`.

## Usage

``` r
config_schema()
```

## Value

Named list shaped like
[`default_config()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/default_config.md).
