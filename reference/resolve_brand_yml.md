# Resolve the active \_brand.yml for template rendering

Prefers the single-app location (`src/app`); for multi-app, falls back
to the first listed app if the shared location has no brand file.

## Usage

``` r
resolve_brand_yml(output_dir, is_multi_app, apps_manifest)
```
