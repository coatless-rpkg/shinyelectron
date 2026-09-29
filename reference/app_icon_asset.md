# Build path of a suite app's launcher icon

[`copy_brand_assets()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/copy_brand_assets.md)
copies each app's `icon` here, and the apps manifest points the launcher
at it.

## Usage

``` r
app_icon_asset(app)
```

## Arguments

- app:

  List. One `apps` entry, with its `icon` already resolved.

## Value

`"assets/apps/<id>.<ext>"`, relative to the Electron project, or `NULL`
when the app has no icon.
