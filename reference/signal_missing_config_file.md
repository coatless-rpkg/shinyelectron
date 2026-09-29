# Report a configured file that does not exist

Names the key and the absolute path that was checked, and says what
happens next.

## Usage

``` r
signal_missing_config_file(
  field,
  path,
  consequence = NULL,
  base_dir = NULL,
  app_id = NULL,
  error = FALSE,
  call = parent.frame()
)
```

## Arguments

- field:

  Character. The key, such as `"splash.image"`.

- path:

  The configured value.

- consequence:

  Character. What the build does without the file.

- base_dir:

  Character or `NULL`. The directory relative paths in
  `_shinyelectron.yml` were resolved against. `NULL` for a configuration
  passed straight to
  [`build_electron_app()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/build_electron_app.md),
  whose relative paths are taken from the working directory.

- app_id:

  Character or `NULL`. The suite app the key belongs to.

- error:

  Logical. Whether to stop instead of warning.

- call:

  Environment. The function the error is reported from.
