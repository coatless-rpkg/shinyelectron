# Evaluate an expression, collecting its warnings and error

Records every warning `expr` gives, in order, and lets it carry on, so
[`app_check()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/app_check.md)
can report each one. An error ends the evaluation; the warnings given
before it are kept.

## Usage

``` r
catch_conditions(expr)
```

## Arguments

- expr:

  An expression, evaluated in the calling function's environment.

## Value

A list with `value`, the value of `expr` or `NULL` after an error,
`error`, the error condition or `NULL`, and `warnings`, the messages of
the warnings given.
