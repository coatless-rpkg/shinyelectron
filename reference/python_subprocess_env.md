# Environment for spawning Python child processes

R prepends its own and related library directories to `LD_LIBRARY_PATH`
(its lib directory plus system paths such as
`/usr/lib/x86_64-linux-gnu`). When a Python child inherits that, the
dynamic loader can resolve a *system* `libpython` ahead of the
interpreter's own; the interpreter then computes a different
`sys.prefix` and its `site` module drops `site-packages` from
`sys.path`, so pip-installed packages (for example the Python
`shinylive` CLI) become unimportable and the process fails with
`No module named ...` even though the package is installed. Python
resolves its own libraries via rpath, so `LD_LIBRARY_PATH` is removed
for Python children. A no-op on platforms / installs where it is not set
(Windows, macOS, most user setups).

## Usage

``` r
python_subprocess_env()
```

## Value

A named character vector suitable for the `env` argument of
[`processx::run()`](http://processx.r-lib.org/reference/run.md).
