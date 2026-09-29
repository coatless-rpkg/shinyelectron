# Project path of the Windows installer license

The license file is copied into the generated project's build resources
under a fixed name. Names that electron-builder finds on its own, such
as `license.txt` or `eula.txt`, are avoided because they would also add
the license to other targets, for example as a Linux AppImage EULA. The
extension is kept (lowercased) since electron-builder shows `.html`
licenses differently from plain text and RTF. electron-builder only
recognizes the `.html` suffix, so `.htm` becomes `.html`; a file without
an extension is treated as plain text.

## Usage

``` r
installer_license_path(license_file)
```

## Arguments

- license_file:

  Character. Path to the license file.

## Value

Character. The license path relative to the Electron project.
