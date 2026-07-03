# System Requirements Situation Report

Checks system requirements for shinyelectron including Node.js, npm,
operating system, and architecture.

## Usage

``` r
sitrep_electron_system(verbose = TRUE)
```

## Arguments

- verbose:

  Logical. Whether to print detailed output. Default is TRUE.

## Value

Invisibly returns a list with diagnostic information.

## Examples

``` r
# \donttest{
# Check system requirements
sitrep_electron_system()
#> 
#> ── System Requirements Report ──────────────────────────────────────────────────
#> ✔ Platform: linux
#> ✔ Architecture: x64
#> ℹ Local Node.js (shinyelectron): Not installed
#> ℹ   Install with: `shinyelectron::install_nodejs()`
#> ✔ Active Node.js: v22.23.1 (system)
#> ! npm: v10.9.8 (version 11.5.0+ required)
#> ✔ R: v4.6.1
#> 
#> ── Python ──
#> 
#> ✔ Python 3.12.3
#> ℹ Python shinylive: not usable
#> ℹ   Install with: `pip install shinylive`
#> ℹ Python shiny: not usable
#> ℹ   Install with: `pip install shiny`
#> 
#> ── Container Engine ──
#> 
#> ✔ Container engine: docker
#> 
#> ── Cached Runtimes ──
#> 
#> ℹ No cached runtimes found
#> ! Found 1 issue
#> 
#> ── Recommendations ──
#> 
#> ℹ Update npm with: npm install -g npm@latest

# Get diagnostic info without printing
info <- sitrep_electron_system(verbose = FALSE)
# }
```
