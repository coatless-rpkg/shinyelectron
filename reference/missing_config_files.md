# Find the optional configured files that do not exist

The splash image, the tray icon and the launcher icon of each suite app
are optional: without them the build uses a default.

## Usage

``` r
missing_config_files(config)
```

## Arguments

- config:

  List. The configuration.

## Value

A list with one element per missing file. Each is a list with `field`
(the key), `path`, `consequence` (what the build uses instead), and
either `key` (the location in `config`) or `app` (the index in
`config$apps`) and `id`.
