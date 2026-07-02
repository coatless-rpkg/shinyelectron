# Resolve Posit brand.yml palette references

In a brand.yml `color` block the semantic roles (`primary`,
`background`, `foreground`, ...) may either hold a colour directly or
name an entry in `color.palette`. shinyelectron reads these roles
verbatim for the Electron shell, so a reference such as `primary: plum`
must be resolved to its palette value before use. Roles that already
hold a literal colour are left untouched.

## Usage

``` r
resolve_brand_palette(brand)
```

## Arguments

- brand:

  List or NULL. Parsed `_brand.yml` contents.

## Value

The brand list with `color` roles resolved against `color.palette`.
