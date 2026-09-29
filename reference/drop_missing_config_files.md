# Warn about and drop the optional configured files that do not exist

Dropping the key makes the build use its default instead of referring to
a file that is never copied.
[`export()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/export.md)
calls this once the paths are resolved, and
[`process_templates()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/process_templates.md)
calls it again for a configuration passed straight to
[`build_electron_app()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/build_electron_app.md).

## Usage

``` r
drop_missing_config_files(config, base_dir = NULL)
```

## Arguments

- config:

  List. The configuration.

- base_dir:

  Character or `NULL`. The directory relative paths in
  `_shinyelectron.yml` were resolved against, named in the warning.

## Value

`config`, without the missing files.
