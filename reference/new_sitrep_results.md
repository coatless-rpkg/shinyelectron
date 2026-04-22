# Initialize a sitrep results list with the standard shape

Each sitrep function accumulates issues and recommendations as it runs.
This helper ensures all sitrep results expose the same two fields so the
top-level
[`sitrep_shinyelectron()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/sitrep_shinyelectron.md)
aggregator can iterate over them uniformly.

## Usage

``` r
new_sitrep_results(extra = list())
```

## Arguments

- extra:

  Named list of additional fields to merge in.

## Value

List with `issues` and `recommendations` character vectors plus any
extras.
