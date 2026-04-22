# Disable Auto-Updates

Disables automatic update checking in the configuration file.

## Usage

``` r
disable_auto_updates(appdir, verbose = TRUE)
```

## Arguments

- appdir:

  Character path to app directory

- verbose:

  Logical whether to show progress messages. Default `TRUE`.

## Value

Invisibly returns the path to the updated config file.

## Examples

``` r
if (FALSE) { # \dontrun{
disable_auto_updates("path/to/app")
} # }
```
