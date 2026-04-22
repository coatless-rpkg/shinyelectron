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
if (FALSE) { # \dontrun{
# Check current directory
sitrep_electron_project()

# Check specific directory
sitrep_electron_project("path/to/electron/project")
} # }
```
