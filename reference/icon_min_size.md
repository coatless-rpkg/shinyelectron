# Smallest icon image each platform takes

electron-builder makes each platform's icon from the file it is given.
It converts a PNG to a macOS `.icns` file and a Windows `.ico` file, and
uses it as it is for Linux. It converts an `.icns` file to a Windows
icon and a Linux icon set, and gives it to macOS as it is. It cannot
make a macOS icon or a Linux icon set from an `.ico` file, and stops the
build when asked to, so an `.ico` file serves Windows only.

## Usage

``` r
icon_min_size(icon)
```

## Arguments

- icon:

  Character. Path to the app icon.

## Value

Named numeric vector. For each platform that can use the format of
`icon`, the smallest size, in pixels, that it takes, to compare with
[`icon_size()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/icon_size.md).
Empty for another format.

## Details

It also stops the build when the image is too small. A PNG must be at
least 512x512 pixels for macOS and 256x256 for Windows, and an `.icns`
or `.ico` file must hold an image of 256x256 pixels or more for Windows
(a PNG image, in an `.icns` file). Up to version 26.14, electron-builder
needs both sides of a PNG to be that large; later versions look at the
longer side. Linux is not checked. Since version 26.15, which
`npm install` picks for the generated project, electron-builder uses a
PNG of any size as it is for Linux; whether it makes a Linux icon set
from an `.icns` file without such a PNG image depends on the version.
The format is read from the extension, ignoring case.
