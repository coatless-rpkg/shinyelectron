# Infer the default runtime strategy

Returns the passed strategy, or falls back to the package default
(`"shinylive"`) when unset. The `app_type` argument is accepted for
backwards compatibility and ignored.

## Usage

``` r
infer_runtime_strategy(strategy, app_type = NULL)
```

## Arguments

- strategy:

  Character string or NULL. Explicit strategy, or NULL.

- app_type:

  Ignored. Retained for signature compatibility.

## Value

Character string. Either the explicit strategy or `"shinylive"`.
