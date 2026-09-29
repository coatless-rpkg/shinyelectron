# Resolve the file paths in a configuration

Makes every configuration value that names a file on the build machine
absolute with
[`resolve_config_path()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/resolve_config_path.md):
`icon`, `icons.mac`, `icons.win`, `icons.linux`, `splash.image`,
`tray.icon`, `signing.win.certificate_file`, and the `path` and `icon`
of each `apps` entry.
[`export()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/export.md)
calls this right after reading `_shinyelectron.yml`, so the paths no
longer depend on the working directory. An empty string counts as unset
and is removed. Other values that are not a single string are left for
the later checks to report.

## Usage

``` r
resolve_config_paths(config, base_dir)
```

## Arguments

- config:

  List. The merged configuration.

- base_dir:

  Character. The directory that holds `_shinyelectron.yml`.

## Value

`config`, with those paths made absolute.
