# Read \_brand.yml file

Reads a \_brand.yml file from the app directory for visual
customization. Follows the Posit brand.yml specification.

## Usage

``` r
read_brand_yml(appdir)
```

## Arguments

- appdir:

  Character string. Path to the app directory.

## Value

List with brand settings, or NULL if no file found.
