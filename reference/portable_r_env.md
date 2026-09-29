# Environment for processes of a portable R

The caller's environment without `R_ENVIRON` and `R_PROFILE`, so a
portable R reads its own site files instead of site files chosen for the
calling R (callr sets both for the R it starts, and a user can set them
too). On macOS the portable R's `Rprofile.site` rewrites the
shared-library references of the binary packages it installs, which is
what lets them load. The user's environ file and profile and every other
variable are kept.

## Usage

``` r
portable_r_env()
```

## Value

Named character vector for the `env` argument of
[`processx::run()`](http://processx.r-lib.org/reference/run.md).
