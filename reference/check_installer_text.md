# Stop or warn when app text contains `$`

electron-builder passes the app name, description, author's name, and
copyright to NSIS, which builds the Windows installer, without escaping
`$`. NSIS reads `$` as the start of a variable: the build fails on an
unknown one (electron-builder treats NSIS warnings as errors), and a
known one silently changes the text. So a `$` stops an export that
builds a Windows installer, before any conversion, and warns for any
other.

## Usage

``` r
check_installer_text(app_name, config, windows)
```

## Arguments

- app_name:

  Character string. The display name.

- config:

  List. The effective configuration.

- windows:

  Logical. Whether the export builds a Windows installer.

## Value

Invisible `TRUE`; aborts or warns when a value contains `$`.
