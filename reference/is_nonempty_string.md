# Test for a single non-empty string

Template flags use this so an optional setting renders only when it
holds real text: `NULL`, `""`, `NA`, and non-character values all count
as unset.

## Usage

``` r
is_nonempty_string(x)
```

## Arguments

- x:

  Value to test.

## Value

`TRUE` or `FALSE`.
