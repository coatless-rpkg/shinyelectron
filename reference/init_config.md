# Initialize configuration file

Creates a template \_shinyelectron.yml file in the specified directory.

## Usage

``` r
init_config(appdir, app_name = NULL, overwrite = FALSE, verbose = TRUE)
```

## Arguments

- appdir:

  Character path to app directory

- app_name:

  Character application name. If NULL, derived from directory name.

- overwrite:

  Logical whether to overwrite existing config. Default FALSE.

- verbose:

  Logical whether to show progress. Default TRUE.

## Value

Invisibly returns the path to the created config file.

## See also

[`wizard()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/wizard.md)
for an interactive configuration generator;
[`show_config()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/show_config.md)
to display the merged effective configuration.

## Examples

``` r
if (FALSE) { # \dontrun{
# Create config in app directory
init_config("path/to/my/app")

# Create with custom name
init_config("path/to/app", app_name = "My Amazing App")
} # }
```
