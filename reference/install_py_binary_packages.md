# Install Python packages as binary only

Installs Python packages using pip with –only-binary :all: flag.

## Usage

``` r
install_py_binary_packages(
  packages,
  index_url = "https://pypi.org/simple",
  target_dir = NULL,
  verbose = TRUE
)
```

## Arguments

- packages:

  Character vector of package names.

- index_url:

  Character string. PyPI index URL.

- target_dir:

  Character string or NULL. Target directory for installation.

- verbose:

  Logical. Whether to show progress.
