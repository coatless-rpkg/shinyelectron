# Validate icon file for target platform

Checks that the icon file exists and has the correct format for the
target platform. Issues warnings (not errors) for format mismatches so
the build can continue.

## Usage

``` r
validate_icon(icon, platform = NULL)
```

## Arguments

- icon:

  Character path to icon file.

- platform:

  Character vector of target platforms.
