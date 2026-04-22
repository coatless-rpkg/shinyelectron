# Download and extract a portable runtime into a cache directory

Shared helper for
[`install_r()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/install_r.md)
and
[`install_python()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/install_python.md).
Handles the common flow: cache-hit short-circuit, download to temp file,
extract by archive type, verify the expected executable appears,
cleanup.

## Usage

``` r
download_and_extract_portable_tool(
  label,
  version,
  install_path,
  download_url,
  executable_finder,
  force = FALSE,
  is_installed = FALSE,
  verbose = TRUE
)
```

## Arguments

- label:

  Character. Human-readable tool name for messages ("R", "Python").

- version:

  Character. Version string.

- install_path:

  Character. Target cache directory for the extracted archive.
  Already-populated path is returned unless `force` is TRUE.

- download_url:

  Character. URL to the archive.

- executable_finder:

  Function with no arguments that returns the path to the tool's
  executable after extraction, or NULL if not found.

- force:

  Logical. Reinstall even if `install_path` already exists.

- is_installed:

  Logical. Whether the runtime is already present.

- verbose:

  Logical. Whether to print progress messages.

## Value

Invisibly returns the installation path.

## Details

[`install_nodejs()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/install_nodejs.md)
has additional requirements (SHA256 checksums, directory renaming after
extraction) and implements its own flow.
