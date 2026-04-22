# Merge detected Python dependencies with config declarations

Merge detected Python dependencies with config declarations

## Usage

``` r
merge_py_dependencies(detected, config_deps)
```

## Arguments

- detected:

  Character vector of detected package names.

- config_deps:

  List from config\$dependencies.

## Value

List with `packages` (character vector) and `index_urls` (list).
