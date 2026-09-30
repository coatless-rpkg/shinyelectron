# Size of an icon file's image

Reads the header of the file, which electron-builder checks against
[`icon_min_size()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/icon_min_size.md)
before it converts the icon: the width and height of a PNG, the images
listed in an `.ico` file, and, in an `.icns` file, the PNG images of
256x256 pixels or more, which are the ones electron-builder makes a
Windows icon from.

## Usage

``` r
icon_size(icon)
```

## Arguments

- icon:

  Character. Path to the app icon.

## Value

Numeric. The side, in pixels, of the largest square image the file
gives: the shorter side of a PNG, or the largest image of an `.ico` file
or of those in an `.icns` file (0 when there are none). `NA` when the
file cannot be read as the format its extension names.
