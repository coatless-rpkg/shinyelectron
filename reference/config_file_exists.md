# Check that a configured path names an existing file

Check that a configured path names an existing file

## Usage

``` r
config_file_exists(path)
```

## Arguments

- path:

  A configuration value.

## Value

`TRUE` when `path` is a single string naming an existing file (a
directory does not count), otherwise `FALSE`.
