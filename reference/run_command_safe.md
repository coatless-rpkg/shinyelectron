# Run a command safely and return the result

Wraps processx::run with consistent error handling. Returns a list with
status, stdout, and stderr. Never throws — failures are indicated by a
non-zero status.

## Usage

``` r
run_command_safe(command, args = character(), timeout = 30)
```

## Arguments

- command:

  Character command to run.

- args:

  Character vector of arguments.

- timeout:

  Numeric timeout in seconds. Default 30.

## Value

List with status, stdout, stderr.
