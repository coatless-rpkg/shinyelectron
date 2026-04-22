# Build Electron Application

Builds a distributable Electron application from a converted Shiny app.
Creates platform-specific installers and executables.

## Usage

``` r
build_electron_app(
  app_dir,
  output_dir,
  app_name = NULL,
  app_type = "r-shinylive",
  runtime_strategy = "shinylive",
  sign = FALSE,
  platform = NULL,
  arch = NULL,
  icon = NULL,
  config = NULL,
  overwrite = FALSE,
  verbose = TRUE
)
```

## Arguments

- app_dir:

  Character string. Path to the converted Shiny/shinylive application.

- output_dir:

  Character string. Path where the built Electron app will be saved.

- app_name:

  Character string. Name of the application. If NULL, uses the base name
  of app_dir.

- app_type:

  Character string. Type of application: "r-shinylive", "r-shiny",
  "py-shinylive", or "py-shiny".

- runtime_strategy:

  Character string. Runtime strategy: "shinylive", "bundled", "system",
  "auto-download", or "container". Default is "shinylive".

- sign:

  Logical. Whether to enable code signing for the built application.
  Default is FALSE.

- platform:

  Character vector. Target platforms: "win", "mac", "linux". If NULL,
  builds for current platform.

- arch:

  Character vector. Target architectures: "x64", "arm64". If NULL, uses
  current architecture.

- icon:

  Character string. Path to application icon file. Platform-specific
  format required.

- config:

  List. Configuration from \_shinyelectron.yml file (optional). Used for
  template variables like window dimensions, port, and app version.

- overwrite:

  Logical. Whether to overwrite existing output directory. Default is
  FALSE.

- verbose:

  Logical. Whether to display detailed progress information. Default is
  TRUE.

## Value

Character string. Path to the built Electron application directory.

## Details

This function creates a complete Electron application by:

- Setting up the Electron project structure

- Copying application files and templates

- Installing npm dependencies

- Building platform-specific distributables

## Examples

``` r
if (FALSE) { # \dontrun{
# Build Electron app for current platform
build_electron_app(
  app_dir = "path/to/shinylive/app",
  output_dir = "path/to/electron/build",
  app_name = "My Shiny App",
  app_type = "r-shinylive"
)

# Build for multiple platforms
build_electron_app(
  app_dir = "path/to/app",
  output_dir = "path/to/build",
  app_name = "My App",
  app_type = "r-shinylive",
  platform = c("win", "mac", "linux")
)
} # }
```
