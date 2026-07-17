## R CMD check results

0 errors | 0 warnings | 1 note

* This is a new submission.

## Notes explained

* The note "Package has a VignetteBuilder field but no prebuilt vignette index"
  is a known artifact of the quarto vignette engine (quarto::html). The
  vignettes are built into inst/doc and re-build cleanly under R CMD check; the
  engine simply does not register a build/vignette.rds index.

## Test environments

* local: macOS, R 4.6.1
* win-builder: R-devel
