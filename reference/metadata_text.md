# Reduce a metadata setting to one line of text

electron-builder writes the description, copyright, and author name into
single-line fields such as the Windows file properties, so line breaks
become spaces and surrounding whitespace is dropped.

## Usage

``` r
metadata_text(x)
```

## Arguments

- x:

  Value to clean.

## Value

A single string, or `NULL` when `x` is not a string or holds only
whitespace.
