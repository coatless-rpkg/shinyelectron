# Remove test suites and bulky documentation from an embedded R runtime

Shrinks a bundled R runtime by deleting files that a running app does
not read. The removed names form a fixed allowlist; everything else is
kept.

## Usage

``` r
prune_bundled_r_runtime(runtime_dir, verbose = TRUE)
```

## Arguments

- runtime_dir:

  Character. The embedded `runtime/R` directory.

- verbose:

  Logical. Whether to report what was removed.

## Value

Invisibly, a list with the number of `files` and `bytes` removed.

## Details

The allowlist covers:

- From every installed package, both in the bundled library
  (`runtime/R/library`) and among the base and recommended packages in
  the portable R's own library: the test suites in `tests/`, `testme/`
  and `tinytest/`.

- From each portable R distribution (`runtime/R/portable-r-*`): R's
  regression tests in `tests/`, and inside `doc/` the `html/` and
  `manual/` directories plus R's news, FAQ, `CHANGES` and `README`
  files.

Package `examples/`, `demo/`, NEWS and CHANGELOG files and `include/`
headers are kept, because some packages and apps read them at runtime
(for example `shinyjs::runExample()`, a "What's new" panel that shows
`NEWS.md` via
[`system.file()`](https://rdrr.io/r/base/system.file.html), or
[`Rcpp::sourceCpp()`](https://rdrr.io/pkg/Rcpp/man/sourceCpp.html)). In
the portable R's `doc/`, `COPYING`, `COPYRIGHTS` (third-party notices
that binary distributions of R must include), `AUTHORS`, `THANKS`,
`RESOURCES`, the mirror lists read by
[`utils::getCRANmirrors()`](https://rdrr.io/r/utils/chooseCRANmirror.html)
and the `KEYWORDS` files are kept.

Symbolic links are never followed: a link is removed itself, and its
target is neither touched nor counted. The totals count only the regular
files that are actually gone afterwards.
