# Warn when the configured Windows signing certificate does not exist

[`export()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/export.md)
calls this when it signs a Windows build, whether signing was turned on
by the `sign` argument or by `signing.sign`. The key is kept, so
electron-builder still fails on it rather than quietly building an
unsigned installer.

## Usage

``` r
check_config_certificate(config, base_dir = NULL)
```

## Arguments

- config:

  List. The configuration, with paths already resolved.

- base_dir:

  Character or `NULL`. The directory relative paths in
  `_shinyelectron.yml` were resolved against, named in the warning.

## Value

`TRUE` when the certificate is unset or exists, otherwise `FALSE`
(invisibly).
