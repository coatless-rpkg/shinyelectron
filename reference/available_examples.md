# List Available Examples

Shows all bundled example applications with their descriptions.

## Usage

``` r
available_examples()
```

## Value

A data frame with columns: `name` (character ID), `language` (R or
Python), `type` (app type), and `description` (human-readable summary).

## Examples

``` r
available_examples()
#> 
#> ── Available shinyelectron examples ──
#> 
#> 
#> r (R)
#> R Shiny dashboard with runtime detection and interactive plot (works in all
#> strategies including shinylive)
#> 
#> python (Python)
#> Python Shiny dashboard with runtime detection and interactive plot (works in
#> all strategies including shinylive)
#> 
#> suite (R)
#> Multi-app launcher with 3 bslib-themed R Shiny apps
#> 
#> 
#> ── Usage ──
#> 
#> `path <- example_app("r")`
#> `export(path, "my-output", app_type = "r-shiny", runtime_strategy = "system")`
```
