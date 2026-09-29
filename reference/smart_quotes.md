# Replace straight double quotes with typographic ones

electron-builder writes the product name, the copyright, and the
author's name into double-quoted strings of the Windows installer (NSIS)
script without escaping them, so a straight double quote ends the string
and the installer build fails. electron-builder already turns the quotes
in the description into typographic ones; this applies the same rule to
the other values
[`generate_package_json()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/generate_package_json.md)
writes.

## Usage

``` r
smart_quotes(x)
```

## Arguments

- x:

  A string, or `NULL`.

## Value

`x` with each `"` replaced by an opening or closing typographic quote,
or `NULL` when `x` is `NULL`.
