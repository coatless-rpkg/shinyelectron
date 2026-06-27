# Build the container backend configuration

Produces the container-specific settings that are merged into
`backend_config` (see
[`generate_template_variables()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/generate_template_variables.md))
and consumed by `inst/electron/backends/container.js` at runtime. The
configured engine is passed through as-is; image selection and engine
auto-detection happen on the end user's machine in `container.js`.

## Usage

``` r
generate_container_config(config, app_type = NULL)
```

## Arguments

- config:

  List. Full app configuration.

- app_type:

  Character or NULL. Application type (e.g. `"r-shiny"`, `"py-shiny"`).
  Used to resolve the runtime version for `container_tag` when no BYO
  image is configured. When NULL and no tag is configured, falls back to
  `"latest"`.

## Value

Named list of container settings.
