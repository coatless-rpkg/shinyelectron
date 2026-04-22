# Detect available container engine

Searches for Docker or Podman on the system.

## Usage

``` r
detect_container_engine(preference = NULL)
```

## Arguments

- preference:

  Character string or NULL. Preferred engine ("docker" or "podman").

## Value

Character string ("docker" or "podman") or NULL if none found.
