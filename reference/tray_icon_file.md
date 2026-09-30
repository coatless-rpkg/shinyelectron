# File name of the tray icon in the build

[`copy_brand_assets()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/copy_brand_assets.md)
copies `tray.icon` into `assets/` under this name, and `main.js` loads
it from there. The file keeps its own name unless that is the name of
the app icon's copy (see
[`icon_asset_path()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/icon_asset_path.md)),
ignoring case. Then it gets a `tray-` prefix, so that neither copy
replaces the other: every platform's build takes its icon from the app
icon's copy.

## Usage

``` r
tray_icon_file(tray_icon, icon = NULL)
```

## Arguments

- tray_icon:

  Character. Path to the tray icon.

- icon:

  Character path to the app icon, or `NULL`.

## Value

Character. The file name of the copy in `assets/`.
