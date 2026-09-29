# Ask for an app slug when none could be derived

[`init_config()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/init_config.md)
and
[`wizard()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/wizard.md)
write the slug, which comes from the directory name, into the new
configuration. When the directory name has no ASCII letters or digits,
they leave it out and say so with this alert.

## Usage

``` r
alert_missing_slug()
```

## Value

Called for its message.
