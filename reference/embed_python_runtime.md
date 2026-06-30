# Embed a portable Python runtime into a bundled Electron build

Behavior-preserving extraction of the Python bundled-embedding block
from
[`build_electron_app()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/build_electron_app.md).
ALWAYS installs + copies the interpreter so the shared `runtime/Python`
path exists for suite-wide bundled detection; only the pip install is
gated on a non-empty `packages` set. Warn-only (not abort) on pip
failure; the result is not verified, matching the original block.
Reproduces the three `output_dir`-derived paths and the unix-only
fallback glob so the `native-py.js` `sys.path` expectations hold.

## Usage

``` r
embed_python_runtime(
  output_dir,
  packages,
  index_urls,
  version,
  platform,
  arch,
  verbose = TRUE
)
```

## Arguments

- output_dir:

  Character. The Electron app output directory.

- packages:

  Character vector. Python package specs (may be empty/NULL).

- index_urls:

  Character vector. PyPI-like index URLs.

- version:

  Character. Resolved Python version (non-NULL from callers).

- platform:

  Character scalar. Target platform.

- arch:

  Character scalar. Target architecture.

- verbose:

  Logical. Whether to display progress.

## Value

Invisibly, the path to the embedded `runtime/Python` directory.
