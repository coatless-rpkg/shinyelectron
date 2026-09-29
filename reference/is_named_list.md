# Test for a map-like list

`TRUE` for a list whose elements all have non-empty names, the shape
YAML gives a mapping. YAML sequences, scalars and lists with an unnamed
element are not map-like.

## Usage

``` r
is_named_list(x)
```

## Arguments

- x:

  Object to test.

## Value

A single logical.
