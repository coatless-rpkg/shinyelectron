# Autodetect the app type from a directory

Scans `appdir` for Shiny entrypoints and returns the implied language. R
apps may use `app.R` or the pair `server.R` plus `ui.R`. Python apps use
`app.py`. A directory that carries both R and Python entrypoints is
rejected; the multi-app-suite path is the right place to combine them.

## Usage

``` r
detect_app_type(appdir)
```

## Arguments

- appdir:

  Character path to the candidate app directory. Must exist.

## Value

Character, either `"r-shiny"` or `"py-shiny"`.
