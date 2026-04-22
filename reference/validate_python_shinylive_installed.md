# Validate the Python shinylive package CLI is usable

Mirrors the command preference used by
[`convert_py_to_shinylive()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/convert_py_to_shinylive.md):
first the `shinylive` console script on PATH, then `python -m shinylive`
as a fallback. Runs `--version` to confirm the CLI actually executes (an
import check is not enough — shinylive ships no `__main__.py`, so a
package that imports fine can still fail at export time).

## Usage

``` r
validate_python_shinylive_installed()
```

## Value

Invisible character string with the detected shinylive version.
