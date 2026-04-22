# Generate a dependency manifest file

Creates a JSON manifest describing the packages an app needs. This
manifest is written into the Electron app and used by the auto-download
and container strategies to install packages at runtime.

## Usage

``` r
generate_dependency_manifest(
  packages,
  language,
  repos = NULL,
  index_urls = NULL
)
```

## Arguments

- packages:

  Character vector of package names.

- language:

  Character string: "r" or "python".

- repos:

  List of R repository URLs (for language = "r").

- index_urls:

  List of Python index URLs (for language = "python").

## Value

Character string of JSON content.
