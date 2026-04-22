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
if (FALSE) { # \dontrun{
# Check system requirements
sitrep_electron_system()

# Get diagnostic info without printing
info <- sitrep_electron_system(verbose = FALSE)
} # }
```
