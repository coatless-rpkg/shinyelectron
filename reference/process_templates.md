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

- verbose:

  Logical whether to show progress
