# Validate a container engine is available

Checks that Docker or Podman is installed and can be executed.

## Usage

``` r
validate_container_available(preference = NULL)
```

## Arguments

- preference:

  Character string or NULL. Preferred engine.

## Value

Invisible character string with the engine name.
