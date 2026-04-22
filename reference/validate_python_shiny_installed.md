# Validate the Python shiny package is installed

Used by the native `py-shiny` app type. Only checks importability — the
export pipeline spawns `python -m shiny run` at runtime on the user's
machine, not at build time.

## Usage

``` r
validate_python_shiny_installed()
```

## Value

Invisible character string with the detected shiny version.
