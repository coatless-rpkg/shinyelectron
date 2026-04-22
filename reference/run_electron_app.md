# Run Electron Application for Testing

Launches a previously exported Electron application for testing and
debugging without building distributable packages. Pass the
`electron-app` directory from a prior
[`export()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/export.md)
call.

## Usage

``` r
run_electron_app(app_dir, port = 3000, open_devtools = TRUE, verbose = TRUE)
```

## Arguments

- app_dir:

  Character string. Path to the Electron application directory (the
  `electron-app` subdirectory from
  [`export()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/export.md)).

- port:

  Integer. Port number for the development server. Default is 3000.

- open_devtools:

  Logical. Whether to open Chromium DevTools automatically. Default is
  TRUE.

- verbose:

  Logical. Whether to display detailed progress information. Default is
  TRUE.

## Value

Invisibly returns the process object for the running application.

## Details

This function starts the Electron application for testing, which:

- Opens the application in an Electron window

- Optionally opens Chromium DevTools for debugging

- Does NOT build distributable packages (use `export(build = TRUE)` for
  that)

## Examples

``` r
if (FALSE) { # \dontrun{
# Run Electron app in development mode
run_electron_app("path/to/electron/app")

# Run with custom port and no dev tools
run_electron_app(
  app_dir = "path/to/app",
  port = 8080,
  open_devtools = FALSE
)
} # }
```
