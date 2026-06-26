# Get path to local npm executable

Get path to local npm executable

## Usage

``` r
npm_executable(version = NULL, platform = NULL, arch = NULL)
```

## Arguments

- version:

  Character Node.js version (NULL = latest installed)

- platform:

  Character target platform (NULL = current)

- arch:

  Character target architecture (NULL = current)

## Value

Character path to npm executable, or NULL if not found
