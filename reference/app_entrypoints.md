# Inspect an app directory for Shiny entrypoints

Returns a named list of logical flags for each entrypoint file. Used by
the detector and by structure validators to avoid duplicating
[`fs::file_exists`](https://fs.r-lib.org/reference/file_access.html)
calls.

## Usage

``` r
app_entrypoints(appdir)
```

## Arguments

- appdir:

  Character path to the candidate app directory.

## Value

Named list with elements `app_py`, `app_r`, `server_r`, `ui_r`.
