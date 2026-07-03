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
# Disable updates on a temporary app
app <- file.path(tempdir(), "disable-updates-demo")
dir.create(app, showWarnings = FALSE)
writeLines("library(shiny)", file.path(app, "app.R"))
enable_auto_updates(app, owner = "myusername", repo = "myapp", verbose = FALSE)
disable_auto_updates(app)
#> ✔ Auto-updates disabled
```
