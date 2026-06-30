# Validate that each language uses a single native runtime strategy

Native strategies (`system`, `bundled`, `auto-download`) share one
backend module and one suite-wide runtime detection per language, so a
suite may declare at most one distinct native strategy per language.
`shinylive` and `container` apps use their own backends and are exempt.

## Usage

``` r
validate_suite_strategies(apps, config)
```

## Arguments

- apps:

  List. `config$apps` entries.

- config:

  List. Full suite configuration.
