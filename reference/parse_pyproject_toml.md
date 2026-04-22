# Parse pyproject.toml dependencies section

Simple parser for the `[project] dependencies` array in pyproject.toml.
Does not handle complex TOML – just extracts quoted dependency strings.

## Usage

``` r
parse_pyproject_toml(path)
```

## Arguments

- path:

  Character string. Path to pyproject.toml.

## Value

Character vector of package names.
