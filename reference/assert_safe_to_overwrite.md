# Refuse to overwrite a protected directory

Aborts with an informative error when `dir` resolves to a well-known
system path (`~`, `/`, [`R.home()`](https://rdrr.io/r/base/Rhome.html))
or a path whose absolute form is three characters or fewer (covers drive
roots such as `C:\` on Windows).

## Usage

``` r
assert_safe_to_overwrite(dir)
```

## Arguments

- dir:

  Character string. Path to check.

## Value

Invisible `TRUE` when the path is safe.
