# Parse pyproject.toml dependencies section

Simple parser for the `[project] dependencies` array in pyproject.toml,
where PEP 621 lists runtime dependencies. `dependencies` arrays in other
tables, such as Hatch's `[tool.hatch.envs.*]` environments, are ignored.
Entries may use double or single quotes, and `#` comments are skipped.
Does not handle complex TOML such as multi-line strings, a quoted
`["project"]` header, or a dotted `project.dependencies` key.

## Usage

``` r
parse_pyproject_toml(path)
```

## Arguments

- path:

  Character string. Path to pyproject.toml.

## Value

Character vector of package names.
