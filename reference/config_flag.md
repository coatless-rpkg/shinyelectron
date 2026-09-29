# Read a true/false setting from the configuration

YAML's unquoted `true` and `false` (and `yes` and `no`, which the YAML
parser also reads as logical) pass through. A quoted `"true"`,
`"false"`, `"yes"` or `"no"`, in any case, is read as the matching
logical with a warning, because a quoted value is easy to write by
accident and earlier versions passed it through. Anything else stops
with an error that names the key.

## Usage

``` r
config_flag(value, field, default = NULL)
```

## Arguments

- value:

  Value read from the configuration.

- field:

  Character. Dotted name of the key, used in messages.

- default:

  Value returned when `value` is `NULL`.

## Value

`TRUE`, `FALSE`, or `default`.
