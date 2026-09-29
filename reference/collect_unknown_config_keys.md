# Collect unknown configuration keys

Compares the keys in the config file against the accepted keys
([`config_schema()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/config_schema.md))
and returns the dotted paths of any key that would otherwise be silently
ignored. It descends only where both the config value and the default
are named lists, the rule
[`merge_config_deep()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/merge_config_deep.md)
uses, so a value that the merge takes whole is not inspected: free-form
maps (`container.volumes`, `container.env`), values whose default is a
list (`dependencies.r.repos`), the entries of the multi-app `apps` list
and the top-level `icon` shortcut.

## Usage

``` r
collect_unknown_config_keys(
  config,
  defaults = config_schema(),
  path = character(0)
)
```

## Arguments

- config:

  List. User configuration parsed from the YAML file.

- defaults:

  List. Schema to compare against (defaults to the full schema).

- path:

  Character vector. Internal recursion path.

## Value

Character vector of unknown dotted key paths (possibly empty).
