# Convert Python Shiny Application to Shinylive

Converts a Python Shiny application directory into a shinylive
application that can run entirely in the browser using Pyodide.

## Usage

``` r
convert_py_to_shinylive(appdir, output_dir, overwrite = FALSE, verbose = TRUE)
```

## Arguments

- appdir:

  Character string. Path to the directory containing the Python Shiny
  application.

- output_dir:

  Character string. Path where the converted shinylive app will be
  saved.

- overwrite:

  Logical. Whether to overwrite existing output directory. Default is
  FALSE.

- verbose:

  Logical. Whether to display detailed progress information. Default is
  TRUE.

## Value

Character string. Path to the converted shinylive application directory.

## Details

This function converts a Python Shiny application to shinylive format
using the Python `shinylive` package. The application will run entirely
in the browser using Pyodide (Python compiled to WebAssembly).

**Requirements:**

- Python 3 must be available on the build machine

- The Python `shinylive` package must be installed
  (`pip install shinylive`)

- The app directory must contain an `app.py` file

## Examples

``` r
if (FALSE) { # \dontrun{
convert_py_to_shinylive(
  appdir = "path/to/python/shiny/app",
  output_dir = "path/to/shinylive/output"
)
} # }
```
