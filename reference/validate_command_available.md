# Validate a command is available and executable

Shared pattern: resolve a command, abort if not found, run it with a
version flag, abort if execution fails. Returns the resolved command.

## Usage

``` r
validate_command_available(
  command_resolver,
  not_found,
  label = "Command",
  version_arg = "--version"
)
```

## Arguments

- command_resolver:

  Function returning the command path or NULL.

- not_found:

  Character vector passed to cli::cli_abort when the command is not
  found. Use "i" = "..." entries for install hints.

- label:

  Character string used in the generic "found but failed" message.
  Defaults to "Command".

- version_arg:

  Character. Argument used to check the command runs. Defaults to
  "–version".

## Value

Invisibly returns the resolved command path.
