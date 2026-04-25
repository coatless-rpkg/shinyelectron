# Check Shiny Application Readiness for Export

Validates that a Shiny application can be built as an Electron app.
Checks app structure, configuration, runtime availability, dependencies,
and signing credentials. Reports issues without aborting.

## Usage

``` r
app_check(
  appdir = ".",
  app_type = NULL,
  runtime_strategy = NULL,
  platform = NULL,
  sign = NULL,
  verbose = TRUE
)
```

## Arguments

- appdir:

  Character string. Path to the app directory. Default ".".

- app_type:

  Character string or NULL. App type override. If NULL, reads from
  config or autodetects from files in `appdir`.

- runtime_strategy:

  Character string or NULL. Runtime strategy override.

- platform:

  Character vector or NULL. Target platforms override.

- sign:

  Logical or NULL. Signing override.

- verbose:

  Logical. Whether to print the report. Default TRUE.

## Value

Invisible list with:

- pass:

  Logical. TRUE if no errors found.

- errors:

  Character vector of fatal issues.

- warnings:

  Character vector of non-fatal issues.

- info:

  Character vector of informational notes.

## Examples

``` r
if (FALSE) { # \dontrun{
# Check current directory
app_check()

# Check specific app
app_check("path/to/my/app")

# Check with overrides
app_check("my-app", app_type = "r-shiny", runtime_strategy = "system")
} # }
```
