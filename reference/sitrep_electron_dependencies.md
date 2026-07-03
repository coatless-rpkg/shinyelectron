# Dependencies Situation Report

Checks R package dependencies required for shinyelectron functionality.

## Usage

``` r
sitrep_electron_dependencies(verbose = TRUE)
```

## Arguments

- verbose:

  Logical. Whether to print detailed output. Default is TRUE.

## Value

Invisibly returns a list with dependency information.

## Examples

``` r
# Check R package dependencies (quiet = returns a list invisibly)
deps <- sitrep_electron_dependencies(verbose = FALSE)
length(deps$missing_required)
#> [1] 0

# \donttest{
# Pretty-printed report
sitrep_electron_dependencies()
#> 
#> ── Dependencies Report ─────────────────────────────────────────────────────────
#> 
#> ── Required Packages ──
#> 
#> ✔ cli: v3.6.6
#> ✔ fs: v2.1.0
#> ✔ jsonlite: v2.0.0
#> ✔ rappdirs: v0.3.4
#> ✔ whisker: v0.4.1
#> ✔ processx: v3.9.0
#> ✔ yaml: v2.3.12
#> ✔ utils: v4.6.1
#> ✔ tools: v4.6.1
#> 
#> ── Optional Packages ──
#> 
#> ✔ shinylive: v0.5.0
#> ℹ DT: Not installed (optional)
#> ℹ ggplot2: Not installed (optional)
#> ✔ All required dependencies satisfied
#> 
#> ── Recommendations ──
#> 
#> ℹ For full functionality, install optional packages with: install.packages(c("DT", "ggplot2"))
# }
```
