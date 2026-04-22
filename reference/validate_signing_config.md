# Validate code signing configuration

Checks that required credentials are available when signing is enabled.
Issues warnings (not errors) for missing credentials so the build can
continue – electron-builder will handle the actual failure.

## Usage

``` r
validate_signing_config(config, platform = NULL)
```

## Arguments

- config:

  List. The effective configuration.

- platform:

  Character string. Target platform ("mac", "win", "linux").
