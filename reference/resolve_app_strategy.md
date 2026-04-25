# Resolve the runtime strategy for a multi-app entry

Order of precedence: explicit per-app `runtime_strategy`, then legacy
per-app type (forces `"shinylive"`), then suite-level
`build.runtime_strategy`, then the package default `"shinylive"`.

## Usage

``` r
resolve_app_strategy(app, config)
```

## Arguments

- app:

  List. Single app entry from config\$apps.

- config:

  List. Full configuration.

## Value

Character string. The resolved runtime strategy.
