# Resolve the Windows installer license against the app directory

`installer.license_file` is written relative to the app directory, while
electron-builder runs inside the generated Electron project. Resolving
the path up front lets the build copy the file into the project, and
stops on a missing file before any runtime is downloaded.

## Usage

``` r
resolve_installer_license(config, appdir)
```

## Arguments

- config:

  List. The effective configuration.

- appdir:

  Character. The app directory the configuration was read from.

## Value

`config`, with `installer$license_file` made absolute when it is set.
