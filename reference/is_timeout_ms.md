# Check a lifecycle timeout value

Check a lifecycle timeout value

## Usage

``` r
is_timeout_ms(x)
```

## Arguments

- x:

  Value to check.

## Value

`TRUE` if `x` is a single whole number of milliseconds between 1000 and
2147483647 (the largest R integer), otherwise `FALSE`.
