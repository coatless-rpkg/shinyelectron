# Detect Python package dependencies from requirements files

Reads `requirements.txt` or `pyproject.toml` to determine Python package
dependencies. Does NOT parse import statements – the
module-name-to-package-name mapping (e.g., `import cv2` maps to
`opencv-python`) makes import parsing unreliable.

## Usage

``` r
detect_py_dependencies(appdir)
```

## Arguments

- appdir:

  Character string. Path to the app directory.

## Value

Character vector of unique package names (sorted).

## Details

Prefers `requirements.txt` over `pyproject.toml` when both exist. Warns
if neither file is found.
