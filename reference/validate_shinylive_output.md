# Validate shinylive output

Validate shinylive output

## Usage

``` r
validate_shinylive_output(output_dir, subdir = NULL)
```

## Arguments

- output_dir:

  Character path to shinylive output (the site root).

- subdir:

  Character or NULL. When set, the app entry lives at
  `output_dir/<subdir>/index.html` and the shared asset tree at
  `output_dir/shinylive/` (multi-app shared-site export). When NULL the
  single-app root layout is checked.
