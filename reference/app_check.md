# Check Shiny Application Readiness for Export

Validates that a Shiny application can be built as an Electron app.
Checks app structure, configuration, build targets, runtime
availability, dependencies, and signing credentials. Reports issues
without aborting.

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

  Character vector or NULL. Target platforms override. If NULL, uses
  `build.platforms` from `_shinyelectron.yml`, then the current
  platform, as
  [`export()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/export.md)
  does. The architectures come from `build.architectures`, then the
  current architecture.

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
stops on it; other missing files are warnings. So is an icon that a
target platform cannot use, because of its format or the size of its
image, since that platform's build shows the default Electron icon, and
an `icons` entry that the build leaves out, since it gives one icon to
every target platform.

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
#> ℹ Architecture(s): "x64"
#> ✔ App structure: app.R found
#> ✔ Node.js: 22.23.2 + npm 10.9.8
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
#> ℹ Architecture(s): "x64"
#> ✔ App structure: app.R found
#> ✔ Node.js: 22.23.2 + npm 10.9.8
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
