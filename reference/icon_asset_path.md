# Project path of the app icon

[`copy_brand_assets()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/copy_brand_assets.md)
copies the app icon into the generated project under this name, and
package.json and `main.js` refer to the copy. The extension is kept,
lowercased: up to version 26.14, electron-builder recognizes the format
of an icon file only by a lower-case extension, and stops the build when
asked to make a Linux icon set from a file named, say, `icon.PNG`.

## Usage

``` r
icon_asset_path(icon)
```

## Arguments

- icon:

  Character. Path to the app icon.

## Value

Character. The icon path relative to the Electron project, such as
`"assets/icon.png"`.
