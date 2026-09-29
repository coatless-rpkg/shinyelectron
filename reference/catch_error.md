# Evaluate an expression and return its error

Lets each check in
[`app_check()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/app_check.md)
record a failure in its own results.

## Usage

``` r
catch_error(expr)
```

## Arguments

- expr:

  An expression, evaluated in the calling function's environment.

## Value

`NULL` when `expr` finishes without an error, otherwise the error
condition.
