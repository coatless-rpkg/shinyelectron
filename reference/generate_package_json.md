# Generate package.json content for Electron app

Programmatically creates the package.json content based on the backend
type and configuration. This replaces the previous Whisker template
approach to avoid fragile JSON + Mustache comma handling.

## Usage

``` r
generate_package_json(
  app_slug,
  app_version,
  backend,
  config,
  has_icon = FALSE,
  sign = FALSE,
  is_multi_app = FALSE,
  app_name = NULL
)
```

## Arguments

- app_slug:

  Character string. The slugified app name.

- app_version:

  Character string. The app version.

- backend:

  Character string. The backend module name without .js (e.g.,
  "shinylive", "native-r").

- config:

  List. The effective configuration.

- has_icon:

  Logical. Whether an icon is provided.

- app_name:

  Character string or NULL. Display name, used as the electron-builder
  productName. `NULL` uses the slug.

## Value

Character string. The JSON content for package.json.
