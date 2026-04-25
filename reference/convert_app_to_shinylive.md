# Convert a Shiny app to the shinylive format

Dispatches to the R or Python shinylive converter based on language.

## Usage

``` r
convert_app_to_shinylive(appdir, destdir, app_type, verbose = TRUE)
```

## Arguments

- appdir:

  Character. Source Shiny app directory.

- destdir:

  Character. Export destination.

- app_type:

  Character. `"r-shiny"` or `"py-shiny"`.

- verbose:

  Logical.

## Value

Character. Path to the converted shinylive app.
