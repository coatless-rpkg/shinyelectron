# Environment for Node.js and npm child processes

npm can be launched by its absolute path, but package lifecycle scripts
invoke `node` by name. When shinyelectron manages a Node.js install that
is not already on `PATH`, this makes that directory discoverable to npm
and every process it starts.

## Usage

``` r
nodejs_subprocess_env()
```

## Value

A character vector for the `env` argument of
[`processx::run()`](http://processx.r-lib.org/reference/run.md) and
[`run_command_safe()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/run_command_safe.md),
or `NULL` when Node.js is already on `PATH` or cannot be resolved (the
inherited environment is then used unchanged).

## Details

The result uses processx's special `"current"` entry so the child
inherits the full parent environment with `PATH` extended, rather than
replacing it. Replacing it would drop variables that npm and
electron-builder depend on (for example `APPDATA` and `LOCALAPPDATA` on
Windows, or `HOME` elsewhere).
