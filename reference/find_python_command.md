# Find the Python command

Searches for python3 first (Unix) or python first (Windows) on the
system PATH and verifies it actually runs (Windows Store aliases exist
but fail).

## Usage

``` r
find_python_command()
```

## Value

Character string or NULL. The Python command name, or NULL if not found.
