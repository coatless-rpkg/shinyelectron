# Project Situation Report

Checks if the current directory contains a valid Electron project and
diagnoses common project-related issues.

## Usage

``` r
sitrep_electron_project(project_dir = ".", verbose = TRUE)
```

## Arguments

- project_dir:

  Character. Path to the project directory. Default is current
  directory.

- verbose:

  Logical. Whether to print detailed output. Default is TRUE.

## Value

Invisibly returns a list with project diagnostic information.

## Examples

``` r
# \donttest{
# Check the current directory for a shinyelectron project
sitrep_electron_project()
#> 
#> ── Project Report ──────────────────────────────────────────────────────────────
#> ℹ Checking directory: /home/runner/work/shinyelectron/shinyelectron/docs/reference
#> ✖ package.json: Not found
#> ! main.js: Not found
#> ✖ App files: Not found in src/app or app/
#> ℹ node_modules: Not found (run 'npm install')
#> ℹ This does not appear to be an Electron project
#> ! Found 3 issues
#> 
#> ── Recommendations ──
#> 
#> ℹ Run 'npm install' to install dependencies
# }

if (FALSE) { # \dontrun{
# Check a specific directory
sitrep_electron_project("path/to/electron/project")
} # }
```
