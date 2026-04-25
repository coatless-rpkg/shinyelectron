# Build the Whisker template variable list for the shared shell

Constructs the named list passed to
[`whisker::whisker.render()`](https://rdrr.io/pkg/whisker/man/whisker.render.html)
when assembling the Electron app. Kept separate from
[`process_templates()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/process_templates.md)
so the variable construction is testable independently.

## Usage

``` r
generate_template_variables(
  app_name,
  app_slug,
  app_type,
  runtime_strategy,
  icon,
  backend_module,
  brand,
  config,
  is_multi_app = FALSE,
  apps_manifest = NULL
)
```

## Arguments

- app_name:

  Character. Display name of the app.

- app_slug:

  Character. Path-safe slug derived from app_name.

- app_type:

  Character. `"r-shiny"` or `"py-shiny"`.

- runtime_strategy:

  Character. Resolved runtime strategy.

- icon:

  Character path to icon file, or NULL.

- backend_module:

  Character. Resolved backend filename (e.g., "native-r.js").

- brand:

  List or NULL. Parsed `_brand.yml` contents if present.

- config:

  List. Effective merged configuration.

- is_multi_app:

  Logical.

- apps_manifest:

  List or NULL. Multi-app manifest entries.

## Value

Named list suitable for Whisker rendering.

## Details

Every variable here corresponds to a `{{...}}` placeholder in
`inst/electron/shared/main.js`, `lifecycle.html`, `preload.js`, or
`launcher.html`. Adding a new placeholder requires adding it here.
