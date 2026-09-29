# Copy the Windows installer license into the build

electron-builder runs inside the generated project, so the file named by
`installer.license_file` is copied to
[`installer_license_path()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/installer_license_path.md),
which
[`build_nsis_config()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/build_nsis_config.md)
references as the NSIS `license`.
[`export()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/export.md)
has already resolved the path against the app directory; a config passed
directly to
[`build_electron_app()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/build_electron_app.md)
uses paths relative to the working directory. A plain-text copy is
passed through
[`add_utf8_bom()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/add_utf8_bom.md)
so NSIS reads it as UTF-8.

## Usage

``` r
copy_installer_license(output_dir, config)
```

## Arguments

- output_dir:

  Character. The Electron project directory.

- config:

  List. The effective configuration.

## Value

Invisibly, the path of the copy, or `NULL` when no license is set.
