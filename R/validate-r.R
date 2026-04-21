#' Validate R is available on the system
#'
#' Checks that Rscript can be found and executed. Used by the "system"
#' runtime strategy where the end user must have R installed.
#'
#' @return Invisible character string with the path to Rscript.
#' @keywords internal
validate_r_available <- function() {
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
