# Stop when a runtime strategy cannot build every target

The `bundled` and `auto-download` strategies embed a runtime, or a
manifest for one, for a single platform and architecture, and it would
be packaged into every installer. A build that uses either one needs a
single target.
[`export()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/export.md)
checks this before anything is copied;
[`build_electron_app()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/build_electron_app.md)
and
[`build_multi_app()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/build_multi_app.md)
check it again for direct callers.

## Usage

``` r
check_single_target(
  strategies,
  platform,
  arch,
  apps = NULL,
  from_config = character(0)
)
```

## Arguments

- strategies:

  Character vector. The runtime strategy of the app, or of each app in a
  suite.

- platform, arch:

  Character vectors. The resolved targets.

- apps:

  List or `NULL`. A suite's `apps` entries, in the order of
  `strategies`, to name the app in the error.

- from_config:

  Character vector. The settings that supplied the targets, from
  [`resolve_build_targets()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/resolve_build_targets.md).

## Value

Invisibly `TRUE`. Stops with an error of class
`shinyelectron_single_target` otherwise.
