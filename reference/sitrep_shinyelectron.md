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
if (FALSE) { # \dontrun{
# Complete diagnostic check
sitrep_shinyelectron()

# Check specific project
sitrep_shinyelectron("path/to/project")

# Get results without printing
results <- sitrep_shinyelectron(verbose = FALSE)
} # }
```
