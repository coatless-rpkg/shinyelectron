# Interactive Configuration Wizard

Walks through setup questions and generates a \_shinyelectron.yml
configuration file for your Shiny app.

## Usage

``` r
wizard(appdir)
```

## Arguments

- appdir:

  Character string. Path to the app directory.

## Value

Invisible path to the generated config file.

## See also

[`init_config()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/init_config.md)
to create a template config file;
[`show_config()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/show_config.md)
to display the merged effective configuration.

## Examples

``` r
if (FALSE) { # interactive()
wizard(tempdir())
}
```
