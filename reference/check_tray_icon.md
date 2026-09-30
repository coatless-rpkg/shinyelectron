# Warn when the tray cannot read its icon on a target platform

The tray shows `tray.icon`, or else the app icon. `main.js` loads the
file with Electron's `nativeImage`, which reads PNG and JPEG files on
every platform and ICO files only on Windows, and cannot read an `.icns`
file. Where it cannot read the file, the tray shows a default icon
instead. When the tray is enabled, this warns about the target platforms
where that happens, judging the file by its extension.

## Usage

``` r
check_tray_icon(config, icon, platform = NULL)
```

## Arguments

- config:

  List. The effective configuration.

- icon:

  Character path to the app icon, or `NULL`.

- platform:

  Character vector of target platforms (`"mac"`, `"win"`, `"linux"`), or
  `NULL` for the current platform.

## Value

Invisibly, the target platforms where the tray cannot read the file, or
`character(0)`.
