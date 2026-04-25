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
  app_type = NULL,
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

  Character string or NULL. Language of the Shiny app: `"r-shiny"` or
  `"py-shiny"`. If NULL (default), the type is autodetected from files
  in `appdir`. The legacy values `"r-shinylive"` and `"py-shinylive"`
  are accepted with a deprecation warning and translate to the canonical
  language plus `runtime_strategy = "shinylive"`.

- runtime_strategy:

  Character string or NULL. How R or Python reaches the end user:
  `"shinylive"`, `"bundled"`, `"system"`, `"auto-download"`, or
  `"container"`. Default `"shinylive"` when neither argument nor config
  sets one.

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

## Supported Combinations

Two languages, five delivery strategies.

- `r-shiny` or `py-shiny` plus `runtime_strategy = "shinylive"`: app
  compiles to WebAssembly and runs inside the Electron window with no
  runtime on disk.

- `r-shiny` or `py-shiny` plus `"auto-download"`, `"bundled"`,
  `"system"`, or `"container"`: app runs against a real R or Python
  process supplied by the chosen strategy.

## Examples

``` r
if (FALSE) { # \dontrun{
# Simplest call: app_type autodetects, runtime_strategy defaults to shinylive
export(
  appdir = "path/to/shiny/app",
  destdir = "path/to/electron/output"
)

# Run against a real R process instead of shinylive
export(
  appdir = "path/to/shiny/app",
  destdir = "path/to/output",
  runtime_strategy = "bundled"
)

# Pin language explicitly when autodetection is ambiguous
export(
  appdir = "path/to/shiny/app",
  destdir = "path/to/output",
  app_type = "r-shiny",
  runtime_strategy = "system"
)
} # }
```
