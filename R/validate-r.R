#' Validate R is available on the system
#'
#' Checks that Rscript can be found and executed. Used by the "system"
#' runtime strategy where the end user must have R installed.
#'
#' @return Invisible character string with the path to Rscript.
#' @keywords internal
validate_r_available <- function() {
  # Inside R CMD check, Rscript is a shim in R_check_bin/ that does not
  # always round-trip through processx. Since R is demonstrably running us,
  # accept Sys.which() as sufficient evidence and skip the subprocess probe.
  if (nzchar(Sys.getenv("_R_CHECK_PACKAGE_NAME_", ""))) {
    rscript <- Sys.which("Rscript")
    if (nzchar(rscript)) return(invisible(unname(rscript)))
  }

  validate_command_available(
    command_resolver = function() {
      path <- Sys.which("Rscript")
      if (nzchar(path)) path else NULL
    },
    not_found = c(
      "Rscript is required but was not found on the system PATH",
      "i" = "Install R from {.url https://cran.r-project.org/}",
      "i" = "Ensure {.code Rscript} is on your PATH"
    ),
    label = "Rscript"
  )
}
