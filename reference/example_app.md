# Get Path to an Example Application

Returns the path to a bundled example application directory. Use this
path as the `appdir` argument to
[`export()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/export.md).

## Usage

``` r
example_app(name)
```

## Arguments

- name:

  Character string. Name of the example (see
  [`available_examples()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/available_examples.md)).

## Value

Character string. Path to the example app directory.

## Examples

``` r
# Get the path to a bundled example
example_app("r")
#> [1] "/home/runner/work/_temp/Library/shinyelectron/demos/demo-single"
example_app("python")
#> [1] "/home/runner/work/_temp/Library/shinyelectron/demos/demo-py-single"

if (FALSE) { # \dontrun{
# Pass the path to export() to build a desktop app
path <- example_app("r")
export(path, "output", app_type = "r-shiny", runtime_strategy = "system")
} # }
```
