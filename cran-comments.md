## Resubmission

This is a resubmission of the first submission, addressing the reviewer's
feedback:

* Interactive functions and `\dontrun{}`: every `\dontrun{}` example block has
  been replaced. Interactive, installer, and destructive functions (for example
  `wizard()`, `run_electron_app()`, `install_nodejs()`, `cache_clear()`,
  `export()`) now wrap their examples in `if (interactive()) { }`. Read-only
  functions now run their example directly, or under `\donttest{}` writing to
  `tempdir()`.

* Installing packages: nothing installs packages or software during
  `R CMD check`. `install_nodejs()`, `install_python_standalone()`, and
  `install_r_portable()` are explicit, user-invoked installers (not run at load
  time or during checks); their examples are guarded with `if (interactive())`.
  Vignette chunks that show install commands are marked `eval: false`, and the
  tests mock all downloads.

* Writing to the user's home filespace: `wizard()`'s `appdir` argument is now
  required (it previously defaulted to `"."`), so no writing function has a
  default path in the home directory, the package directory, or `getwd()`.
  Every executed example that writes uses `tempdir()`, and the tests use
  `withr::local_tempdir()`.

* Resetting options()/working directory: the package changes no `options()` or
  `par()`. Both `Sys.setenv()` calls (the development server and code signing)
  save the prior values and restore them with `on.exit()`.

## R CMD check results

0 errors | 0 warnings | 1 note

* This is a new submission. The only note reports the maintainer and
  "New submission", which is standard for a first submission.

## Test environments

* local: macOS, R 4.6.1
* win-builder: R-devel
