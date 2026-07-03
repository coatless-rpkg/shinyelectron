# Run a command safely and return the result

Wraps [`processx::run()`](http://processx.r-lib.org/reference/run.md)
with consistent error handling. Returns a list with status, stdout, and
stderr. Never throws: a command that cannot be started, fails, or times
out is reported as a non-zero status, so a diagnostic probe cannot abort
the calling session.

## Usage

``` r
run_command_safe(command, args = character(), timeout = 30, env = NULL)
```

## Arguments

- command:

  Character command to run.

- args:

  Character vector of arguments.

- timeout:

  Numeric timeout in seconds. Default 30.

- env:

  Environment for the child process. `NULL` (the default) inherits the
  current environment; otherwise the supplied value is used, where the
  special `"current"` entry extends rather than replaces it. In every
  case `NODE_COMPILE_CACHE` is added so Node's compile cache is written
  to a temporary directory that is removed when the call returns.

## Value

List with status, stdout, stderr.

## Details

processx is used rather than
[`base::system2()`](https://rdrr.io/r/base/system2.html) because a
modified `env` is honored on every platform (system2's `env` is a no-op
on Windows for programs like node and python), and arguments are passed
as an argv array without shell quoting.
