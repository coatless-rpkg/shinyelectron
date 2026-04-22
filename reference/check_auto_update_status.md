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

Invisibly returns a list with: `enabled` (logical), `provider`
(character or NULL), `repo` (character or NULL), and `settings` (list of
check_on_startup, auto_download, auto_install).

## Examples

``` r
if (FALSE) { # \dontrun{
check_auto_update_status("path/to/app")
} # }
```
