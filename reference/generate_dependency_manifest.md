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
  index_urls = NULL,
  local_packages = character(0)
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

- local_packages:

  Character vector. Names of R packages installed from
  `dependencies.r.local_packages`. They stay in the manifest but are
  left out of the system-requirements lookup, which only knows
  repository packages and rejects the whole query when one name is
  unknown.

## Value

Character string of JSON content.
