# Platforms whose icon can come from the app icon

A platform can use the app icon when electron-builder can make its icon
from the file's format and the image is large enough (see
[`icon_min_size()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/icon_min_size.md)).
When
[`icon_size()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/icon_size.md)
cannot read the size, the format alone decides.

## Usage

``` r
icon_platforms(icon)
```

## Arguments

- icon:

  Character. Path to the app icon.

## Value

Character vector of the platforms (`"win"`, `"mac"`, `"linux"`) that can
use `icon`, empty for another format.
