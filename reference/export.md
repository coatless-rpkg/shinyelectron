# Export Shiny Application as Electron Desktop Application

Main entry point function that wraps the conversion, building, and
optionally running of a Shiny application as an Electron desktop
application.

## Usage

``` r
export(
  appdir,
  destdir,
  app_name = NULL,
  app_type = "r-shinylive",
  runtime_strategy = NULL,
  sign = FALSE,
  platform = NULL,
  arch = NULL,
  icon = NULL,
  overwrite = FALSE,
  build = TRUE,
  run_after = FALSE,
  open_after = FALSE,
  verbose = TRUE
)
```

## Arguments

- appdir:

  Character string. Path to the directory containing the Shiny
  application.

- destdir:

  Character string. Path to the destination directory where the Electron
  app will be created.

- app_name:

  Character string. Name of the application. If NULL, uses the base name
  of appdir.

- app_type:

  Character string. Type of application: "r-shinylive" (default),
  "r-shiny", "py-shinylive", or "py-shiny".

- runtime_strategy:

  Character string or NULL. Runtime strategy for native app types:
  "bundled", "system", "auto-download", or "container". If NULL,
  defaults to "auto-download" for native types. Ignored for shinylive
  types.

- sign:

  Logical. Whether to enable code signing for the built application.
  When TRUE, electron-builder will attempt to sign the app using
  credentials from environment variables or the config file. Default is
  FALSE.

- platform:

  Character vector. Target platforms: "win", "mac", "linux". If NULL,
  builds for current platform.

- arch:

  Character vector. Target architectures: "x64", "arm64". If NULL, uses
  current architecture.

- icon:

  Character string. Path to application icon file. Platform-specific
  format required.

- overwrite:

  Logical. Whether to overwrite existing output directory. Default is
  FALSE.

- build:

  Logical. Whether to build distributable packages. Default is TRUE.

- run_after:

  Logical. Whether to run the application in development mode after
  export. Default is FALSE.

- open_after:

  Logical. Whether to open the generated project directory after export.
  Default is FALSE.

- verbose:

  Logical. Whether to display detailed progress information. Default is
  TRUE.

## Value

List containing paths to the converted app and built Electron app (if
built).

## Details

This is the main function of the package that orchestrates the entire
process:

- Validates the input Shiny application

- Converts the Shiny app to the specified format (shinylive by default)

- Sets up the Electron project structure

- Optionally builds distributable packages

- Optionally runs the application for testing

## Supported Application Types

- `r-shinylive`: R Shiny app converted to run entirely in browser
  (recommended)

- `r-shiny`: R Shiny app with embedded R runtime

- `py-shinylive`: Python Shiny app converted to run entirely in browser

- `py-shiny`: Python Shiny app with embedded Python runtime

## Examples

``` r
if (FALSE) { # \dontrun{
# Basic export to shinylive Electron app
export(
  appdir = "path/to/shiny/app",
  destdir = "path/to/electron/output"
)

# Export with custom settings
export(
  appdir = "path/to/shiny/app",
  destdir = "path/to/output",
  app_name = "My Amazing App",
  app_type = "r-shinylive",
  platform = c("win", "mac"),
  icon = "path/to/icon.ico",
  overwrite = TRUE,
  run_after = TRUE
)

# Export regular Shiny app (with R runtime)
export(
  appdir = "path/to/shiny/app",
  destdir = "path/to/output",
  app_type = "r-shiny"
)

} # }
```
