# Run Electron Application in Development Mode

Runs the Electron application in development mode for testing and
debugging. This allows you to test your application before building
distributable packages.

## Usage

``` r
run_electron_app(app_dir, port = 3000, open_devtools = TRUE, verbose = TRUE)
```

## Arguments

- app_dir:

  Character string. Path to the Electron application directory.

- port:

  Integer. Port number for the development server. Default is 3000.

- open_devtools:

  Logical. Whether to open developer tools automatically. Default is
  TRUE.

- verbose:

  Logical. Whether to display detailed progress information. Default is
  TRUE.

## Value

Invisibly returns the process object for the running application.

## Details

This function starts the Electron application in development mode,
which:

- Starts a local development server

- Opens the application in an Electron window

- Enables hot reloading for development

- Provides access to developer tools for debugging

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
