# Copy the top-level contents of one directory into another

`fs::dir_copy(src, dst)` has different semantics across platforms and fs
versions: on some it creates `dst` and copies the contents of `src` into
it, on others it creates `dst/basename(src)/...`. This helper forces the
"copy contents into target" semantics by creating a fresh, empty `dst`
and then copying each top-level entry from `src` into it with base R.

## Usage

``` r
copy_dir_contents(src, dst)
```

## Arguments

- src:

  Character path to the source directory.

- dst:

  Character path to the destination directory. Created if absent; wiped
  if present.

## Value

Invisible `dst`.
