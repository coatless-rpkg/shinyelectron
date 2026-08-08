# Convert Shiny Application to Shinylive

Converts a regular Shiny application directory into a shinylive
application that can run entirely in the browser without requiring an R
server.

## Usage

``` r
convert_shiny_to_shinylive(
  appdir,
  output_dir,
  overwrite = FALSE,
  verbose = TRUE
)
```

## Arguments

- appdir:

  Character string. Path to the directory containing the Shiny
  application.

- output_dir:

  Character string. Path where the converted shinylive app will be
  saved.

- overwrite:

  Logical. Whether to overwrite existing output directory. Default is
  FALSE.

- verbose:

  Logical. Whether to display detailed progress information. Default is
  TRUE.

## Value

Character string. Path to the converted shinylive application directory.

## Details

This function converts a Shiny application to shinylive format, which
allows the application to run entirely in the browser using WebR. The
conversion process:

- Validates the input Shiny application structure

- Converts R code to be compatible with WebR

- Creates necessary shinylive configuration files

- Packages the application for browser execution

## Examples

``` r
if (FALSE) { # \dontrun{
# Convert a Shiny app to shinylive
convert_shiny_to_shinylive(
  appdir = "path/to/shiny/app",
  output_dir = "path/to/shinylive/output"
)
} # }
```
