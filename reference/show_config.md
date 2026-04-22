# Show Effective Configuration

Pretty-prints the merged effective configuration (params + config file +
defaults) for a shinyelectron app directory. Useful for debugging and
verifying settings.

## Usage

``` r
show_config(appdir = ".")
```

## Arguments

- appdir:

  Character path to the app directory.

## Value

Invisibly returns the merged configuration list.

## Examples

``` r
if (FALSE) { # \dontrun{
show_config("path/to/my/app")
} # }
```
