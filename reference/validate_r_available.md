# Validate R is available on the system

Checks that Rscript can be found and executed. Used by the "system"
runtime strategy where the end user must have R installed.

## Usage

``` r
validate_r_available()
```

## Value

Invisible character string with the path to Rscript.
