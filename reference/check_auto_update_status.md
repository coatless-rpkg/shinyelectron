# Check Auto-Update Status

Reports the current auto-update configuration status.

## Usage

``` r
check_auto_update_status(appdir)
```

## Arguments

- appdir:

  Character path to app directory

## Value

Invisibly returns the `updates` configuration list, which is always
present because
[`read_config()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/read_config.md)
deep-merges defaults. Elements include `enabled` (logical, `FALSE` by
default when auto-updates have never been enabled), `provider`
(character), `check_on_startup`, `auto_download`, `auto_install`
(logical), and, for the GitHub provider, `github` (a list with `owner`,
`repo`, `private`).

## Examples

``` r
if (FALSE) { # \dontrun{
check_auto_update_status("path/to/app")
} # }
```
