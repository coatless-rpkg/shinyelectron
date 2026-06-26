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

Invisibly returns the `updates` configuration list, with elements
`enabled` (logical), `provider` (character or NULL), `check_on_startup`,
`auto_download`, `auto_install` (logical), and, for the GitHub provider,
`github` (a list with `owner`, `repo`, `private`). Returns NULL when no
`updates` section is present.

## Examples

``` r
if (FALSE) { # \dontrun{
check_auto_update_status("path/to/app")
} # }
```
