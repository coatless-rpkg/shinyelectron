# Copy branding assets into the build

Copies the app icon (to
[`icon_asset_path()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/icon_asset_path.md)),
the splash image, the tray icon (to
[`tray_icon_file()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/tray_icon_file.md))
and, for a multi-app suite, each app's launcher icon (to
[`app_icon_asset()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/app_icon_asset.md)).
The paths are used as given:
[`export()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/export.md)
has resolved them against the app directory, and
[`process_templates()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/process_templates.md)
has dropped optional files that do not exist.

## Usage

``` r
copy_brand_assets(output_dir, icon, config, apps = NULL)
```

## Arguments

- output_dir:

  Character. The Electron project directory.

- icon:

  Character path to the app icon, or `NULL`.

- config:

  List. The effective configuration.

- apps:

  List or `NULL`. The `apps` entries of a multi-app suite.
