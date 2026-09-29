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

## Details

Files named in `_shinyelectron.yml`, such as `icon` or `splash.image`,
are looked up relative to `appdir`, as
[`export()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/export.md)
does. A missing icon is an error, because
[`export()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/export.md)
stops on it; other missing files are warnings.

## Examples

``` r
# \donttest{
# Check a bundled example app
app_check(example_app("r"))
#> 
#> ── App Check: demo-single ──────────────────────────────────────────────────────
#> ℹ Config: no _shinyelectron.yml (using defaults)
#> ℹ Type: "r-shiny"
#> ℹ Runtime strategy: "shinylive"
#> ℹ Platform(s): "linux"
#> ✔ App structure: app.R found
#> ✔ Node.js: 22.23.3 + npm 10.9.9
#> ✔ shinylive R package: installed
#> ✔ Dependencies: bslib, shiny
#> ℹ Code signing: "disabled"
#> ℹ Icon: not configured (default Electron icon)
#> ✔ App slug: "demo-single"
#> 
#> ── Result ──
#> 
#> ✔ Ready to build! Run: `export("/home/runner/work/_temp/Library/shinyelectron/demos/demo-single", "output")`

# Check with explicit overrides
app_check(example_app("r"), app_type = "r-shiny", runtime_strategy = "system")
#> 
#> ── App Check: demo-single ──────────────────────────────────────────────────────
#> ℹ Config: no _shinyelectron.yml (using defaults)
#> ℹ Type: "r-shiny"
#> ℹ Runtime strategy: "system"
#> ℹ Platform(s): "linux"
#> ✔ App structure: app.R found
#> ✔ Node.js: 22.23.3 + npm 10.9.9
#> ✔ R: available at /usr/local/bin/Rscript
#> ✔ Dependencies: bslib, shiny
#> ℹ Code signing: "disabled"
#> ℹ Icon: not configured (default Electron icon)
#> ✔ App slug: "demo-single"
#> 
#> ── Result ──
#> 
#> ✔ Ready to build! Run: `export("/home/runner/work/_temp/Library/shinyelectron/demos/demo-single", "output")`
# }
```
