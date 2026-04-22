# Generate container configuration JSON

Creates the backend config JSON that container.js reads at runtime.

## Usage

``` r
generate_container_config(app_type, engine, config, app_slug = NULL)
```

## Arguments

- app_type:

  Character string. The app type.

- engine:

  Character string. Container engine.

- config:

  List. Full app configuration.

- app_slug:

  Character string. Slugified app name.

## Value

Character string. JSON content.
