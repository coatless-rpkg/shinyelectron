# Merge detected R dependencies with config declarations

Combines auto-detected packages with user-declared packages from config.
When auto_detect is FALSE, only declared packages are used.

## Usage

``` r
merge_r_dependencies(detected, config_deps)
```

## Arguments

- detected:

  Character vector of detected package names.

- config_deps:

  List from config\$dependencies.

## Value

List with `packages` (character vector) and `repos` (list).
