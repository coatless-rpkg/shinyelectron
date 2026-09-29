# Look up a lifecycle timeout for the generated app

Look up a lifecycle timeout for the generated app

## Usage

``` r
lifecycle_timeout(config, key)
```

## Arguments

- config:

  List. Effective configuration.

- key:

  Character. `"startup_timeout"` or `"shutdown_timeout"`.

## Value

Integer milliseconds: the configured value, or the default when it is
missing or invalid (for example a config that skipped
[`validate_config()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/validate_config.md)).
