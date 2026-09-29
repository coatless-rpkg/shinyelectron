# Get a nested configuration value

Get a nested configuration value

## Usage

``` r
config_value(config, key)
```

## Arguments

- config:

  List. The configuration.

- key:

  Character vector. The names leading to the value, such as
  `c("splash", "image")`.

## Value

The value, or `NULL` when any level is missing.
