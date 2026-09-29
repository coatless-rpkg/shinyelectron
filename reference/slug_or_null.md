# Slugify a name, or return NULL when nothing usable is left

Slugify a name, or return NULL when nothing usable is left

## Usage

``` r
slug_or_null(name)
```

## Arguments

- name:

  The name to slugify. Anything but a single non-empty string gives
  `NULL`.

## Value

The
[`slugify()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/slugify.md)
result, or `NULL` when the name has no ASCII letters or digits.
