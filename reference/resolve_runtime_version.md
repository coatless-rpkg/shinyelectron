# Resolve the runtime version to use for a build

Precedence: an explicit `dependencies.<runtime>.version` in config wins;
the literal `"latest"` calls the live resolver; otherwise the maintained
pin in `SHINYELECTRON_DEFAULTS$runtime_versions` is used.

## Usage

``` r
resolve_runtime_version(runtime, config)
```

## Arguments

- runtime:

  One of `"r"`, `"python"`, `"electron"`.

- config:

  Full app configuration list.

## Value

Character version string.
