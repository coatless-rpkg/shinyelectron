# Environment for the electron-builder processes

electron-builder 26 reads the notarization team ID only from the
`APPLE_TEAM_ID` environment variable; its configuration has no field for
it. For a signed build, `signing.mac.team_id` is therefore passed to
electron-builder as `APPLE_TEAM_ID`. A team ID already set in
`APPLE_TEAM_ID` wins, as the build leaves the signing variables the user
set alone. An empty one counts as unset, as it does for
electron-builder.

## Usage

``` r
electron_builder_env(config, sign)
```

## Arguments

- config:

  List. The effective configuration, or `NULL`.

- sign:

  Logical. Whether the build is signed.

## Value

A value for the `env` argument of
[`processx::run()`](http://processx.r-lib.org/reference/run.md): the
result of
[`nodejs_subprocess_env()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/nodejs_subprocess_env.md),
extended with `APPLE_TEAM_ID` when the configuration supplies it.
