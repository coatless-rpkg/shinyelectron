# Get path to local Node.js executable

Get path to local Node.js executable

## Usage

``` r
nodejs_executable(version = NULL, platform = NULL, arch = NULL)
```

## Arguments

- version:

  Character Node.js version (NULL = latest installed)

- platform:

  Character target platform (NULL = current)

- arch:

  Character target architecture (NULL = current)

## Value

Character path to node executable, or NULL if not found
