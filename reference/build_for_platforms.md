# Build for target platforms

Build for target platforms

## Usage

``` r
build_for_platforms(
  output_dir,
  platform,
  arch,
  sign = FALSE,
  config = NULL,
  verbose = TRUE
)
```

## Arguments

- output_dir:

  Character Electron project directory

- platform:

  Character vector of target platforms

- arch:

  Character vector of target architectures

- sign:

  Logical whether to code-sign the build

- config:

  List. The effective configuration, or `NULL`. A signed build passes
  its `signing.mac.team_id` to electron-builder (see
  [`electron_builder_env()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/electron_builder_env.md)).

- verbose:

  Logical whether to show progress
