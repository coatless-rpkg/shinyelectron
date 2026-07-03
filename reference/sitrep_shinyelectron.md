# Complete Situation Report

Runs all diagnostic checks and provides a comprehensive report of your
shinyelectron setup.

## Usage

``` r
sitrep_shinyelectron(project_dir = ".", verbose = TRUE)
```

## Arguments

- project_dir:

  Character. Path to the project directory to check. Default is current
  directory.

- verbose:

  Logical. Whether to print detailed output. Default is TRUE.

## Value

Invisibly returns a list with all diagnostic information.

## Examples

``` r
# \donttest{
# Complete diagnostic check of the current setup
sitrep_shinyelectron()
#> 
#> ── Complete shinyelectron Diagnostic Report ────────────────────────────────────
#> ────────────────────────────────────────────────────────────────────────────────
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
#> ────────────────────────────────────────────────────────────────────────────────
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
#> ────────────────────────────────────────────────────────────────────────────────
#> 
#> ── Build Tools Report ──────────────────────────────────────────────────────────
#> ℹ Checking build tools for platform: linux
#> ✔ Build tools (gcc, make): Found
#> ✔ Build tools ready
#> ────────────────────────────────────────────────────────────────────────────────
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
#> ────────────────────────────────────────────────────────────────────────────────
#> 
#> ── Overall Summary ─────────────────────────────────────────────────────────────
#> ! Found 4 total issues that may prevent successful builds
#> 
#> ── Priority Actions ──
#> 
#> ℹ 1. Update npm with: npm install -g npm@latest
#> ℹ 2. For full functionality, install optional packages with: install.packages(c("DT", "ggplot2"))
#> ℹ 3. Run 'npm install' to install dependencies

# Get results as a list, without printing
results <- sitrep_shinyelectron(verbose = FALSE)
# }

if (FALSE) { # \dontrun{
# Check a specific project directory
sitrep_shinyelectron("path/to/project")
} # }
```
