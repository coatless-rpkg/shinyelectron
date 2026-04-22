# Select the appropriate container image for an app type

Select the appropriate container image for an app type

## Usage

``` r
select_container_image(app_type, image = NULL, tag = "latest")
```

## Arguments

- app_type:

  Character string. The app type.

- image:

  Character string or NULL. Custom image override.

- tag:

  Character string. Image tag (default: "latest").

## Value

Character string. Full image reference.
