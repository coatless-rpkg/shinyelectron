# Read configuration file

Reads and parses \_shinyelectron.yml from the app directory. If the file
doesn't exist, returns default configuration.

## Usage

``` r
read_config(appdir)
```

## Arguments

- appdir:

  Character path to app directory

## Value

List of configuration values (merged with defaults)
