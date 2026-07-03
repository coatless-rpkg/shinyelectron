# Show Effective Configuration

Pretty-prints the merged effective configuration (params + config file +
defaults) for a shinyelectron app directory. Useful for debugging and
verifying settings.

## Usage

``` r
show_config(appdir = ".")
```

## Arguments

- appdir:

  Character path to the app directory.

## Value

Invisibly returns the merged configuration list.

## Examples

``` r
# Show the merged configuration for a bundled example app
show_config(example_app("r"))
#> 
#> ── shinyelectron Configuration ─────────────────────────────────────────────────
#> ! No config file found, showing defaults only
#> 
#> 
#> ── Application ──
#> 
#> • Name: "demo-single"
#> • Version: "1.0.0"
#> • Slug: "demo-single"
#> 
#> ── Build ──
#> 
#> • Type: "(autodetect)"
#> • Runtime strategy: "shinylive"
#> • Platforms: "linux"
#> • Architectures: "x64"
#> 
#> ── Window ──
#> 
#> • Size: 1200x800
#> • Port: 3838
#> 
#> ── Features ──
#> 
#> • Tray: FALSE
#> • Menu: TRUE
#> • Auto-updates: FALSE
#> • Code signing: FALSE
#> 
#> ── Lifecycle ──
#> 
#> • Prompt before install: FALSE
#> • Prompt runtime version: FALSE
#> • Custom splash: FALSE

if (FALSE) { # \dontrun{
show_config("path/to/my/app")
} # }
```
