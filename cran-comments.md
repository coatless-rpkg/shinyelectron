## R CMD check results

0 errors | 0 warnings | 1 note

* This is a new submission.

## Notes explained

* The word "natively" flagged in DESCRIPTION as possibly misspelled is spelled
  correctly. It describes applications that run natively on each operating
  system.

* The note "Package has a VignetteBuilder field but no prebuilt vignette index"
  is a known artifact of the quarto vignette engine (quarto::html). The
  vignettes are built into inst/doc and re-build cleanly under R CMD check; the
  engine simply does not register a build/vignette.rds index.

* The URL https://www.digicert.com/signing/code-signing-certificates
  (vignettes/code-signing.qmd) resolves normally in a web browser (HTTP 200).
  DigiCert redirects non-browser clients to a health-probe endpoint, which is
  what an automated URL checker follows. The link is correct and points to
  DigiCert's code-signing certificate page.

## Test environments

* local: macOS, R 4.6.1
* win-builder: R-devel
