# Remove allowlisted entries directly under one directory

Matches entry names exactly (case-sensitively). A name in `dir_names` is
removed only when it is a directory, and a name in `file_names` only
when it is a regular file. A symbolic link with a listed name is removed
as a link. Anything else is left untouched, and nothing happens when
`dir` is missing or is itself a symbolic link.

## Usage

``` r
prune_r_paths(dir, dir_names = character(0), file_names = character(0))
```

## Arguments

- dir:

  Character. Directory to prune.

- dir_names, file_names:

  Character vectors of names to remove.

## Value

List with the number of `files` and `bytes` removed.
