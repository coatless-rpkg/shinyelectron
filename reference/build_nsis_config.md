# Build the electron-builder `nsis` block from installer config

Maps `installer.one_click`,
`installer.allow_to_change_installation_directory` and
`installer.per_machine` onto electron-builder's `oneClick`,
`allowToChangeInstallationDirectory` and `perMachine`. Each option is
emitted only when the config sets it, so electron-builder's own defaults
apply otherwise: the one-click installer installs for the current user,
and the wizard (`one_click: false`) asks whether to install for all
users and does not offer a directory page.
[`validate_config()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/validate_config.md)
has already checked the values.

## Usage

``` r
build_nsis_config(config)
```

## Arguments

- config:

  List. The effective configuration.

## Value

A named list for the package.json `build.nsis` field, empty when no
installer option is set.

## Details

`installer.license_file` becomes the NSIS `license`, pointing at the
copy that
[`copy_installer_license()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/copy_installer_license.md)
places in the generated project.
