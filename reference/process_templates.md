# Process and copy Electron templates

Orchestrates the Electron project assembly: renders shared Whisker
templates, copies the appropriate backend modules, sets up Dockerfiles
for container strategy, generates package.json, and copies brand assets.
Each step is a focused helper in this file.

## Usage

``` r
process_templates(
  output_dir,
  app_name,
  app_type,
  runtime_strategy = "shinylive",
  icon = NULL,
  config = NULL,
  sign = FALSE,
  is_multi_app = FALSE,
  apps_manifest = NULL,
  platform = NULL,
  verbose = TRUE
)
```

## Arguments

- output_dir:

  Character destination directory

- app_name:

  Character application display name

- app_type:

  Character application type

- runtime_strategy:

  Character resolved runtime strategy

- icon:

  Character path to icon file or NULL

- config:

  List of configuration values from config file (optional)

- platform:

  Character vector of target platforms, used to check that the tray can
  read its icon (see
  [`check_tray_icon()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/check_tray_icon.md)).
  `NULL` means the current platform.

- verbose:

  Logical whether to show progress
