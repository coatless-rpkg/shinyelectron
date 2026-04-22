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

if (FALSE) { # \dontrun{
# Pretty-printed report
sitrep_electron_dependencies()
} # }
```
