# Map the logging section onto the app section

`_shinyelectron.yml` documents the log settings under a top-level
`logging:` section, while the build reads them from `app.log_dir` and
`app.log_level`, which the file may also set directly. This copies
`logging.log_dir` and `logging.log_level` into `app` on the parsed YAML,
before
[`merge_config_deep()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/merge_config_deep.md)
fills in the defaults. When both spellings set a field to different
values, the `logging` value wins and a warning of class
`shinyelectron_logging_conflict` names the field. Any other key under
`logging` stays in place so that
[`collect_unknown_config_keys()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/collect_unknown_config_keys.md)
reports it. A `logging` value that is not a map, such as
`logging: debug` or a list, is dropped with a warning of class
`shinyelectron_invalid_logging_section`.

## Usage

``` r
map_logging_config(config)
```

## Arguments

- config:

  List. User configuration parsed from the YAML file.

## Value

`config` with the `logging` fields moved into `app`.
