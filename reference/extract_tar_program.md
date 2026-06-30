# Select the tar program used to unpack a `.tar.gz` runtime archive

Windows ships bsdtar (libarchive) at `System32\\tar.exe`. It handles the
PAX / long-name records in python-build-standalone archives that R's
internal tar cannot (those surface as "embedded nul in string" errors),
and unlike a GNU tar from Git for Windows it does not misparse `C:\\...`
paths as remote hosts. Fall back to R's internal tar only when bsdtar is
unavailable. On macOS / Linux the system tar (bsdtar or GNU tar) already
handles PAX records, including the Apple `com.apple.cs.CodeSignature`
xattrs in portable R archives.

## Usage

``` r
extract_tar_program(
  os_type = .Platform$OS.type,
  system_root = Sys.getenv("SystemRoot", unset = "C:\\Windows")
)
```

## Arguments

- os_type:

  Operating system family, defaulting to `.Platform$OS.type`.

- system_root:

  Windows system root, defaulting to the `SystemRoot` environment
  variable.

## Value

A value suitable for the `tar` argument of
[`utils::untar()`](https://rdrr.io/r/utils/untar.html): a path to a tar
executable, the string `"internal"`, or the result of
[`Sys.which()`](https://rdrr.io/r/base/Sys.which.html).
