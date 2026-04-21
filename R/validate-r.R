#' Validate R is available on the system
#'
#' Checks that Rscript can be found and executed. This is used for the
#' "system" runtime strategy where the end user must have R installed.
#'
#' @return Invisible character string with the path to Rscript.
#' @keywords internal
validate_r_available <- function() {
  rscript <- Sys.which("Rscript")

  if (!nzchar(rscript)) {
    cli::cli_abort(c(
      "Rscript is required but was not found on the system PATH",
      "i" = "Install R from {.url https://cran.r-project.org/}",
      "i" = "Ensure {.code Rscript} is on your PATH"
    ))
  }

  tryCatch({
    result <- processx::run(rscript, c("--version"),
                            error_on_status = FALSE, timeout = 10)
    if (result$status != 0) {
      cli::cli_abort(c(
        "Rscript was found but failed to run",
        "x" = "Path: {.path {rscript}}",
        "x" = "Error: {result$stderr}"
      ))
    }
  }, error = function(e) {
    cli::cli_abort(c(
      "Rscript was found but could not be executed",
      "x" = "Path: {.path {rscript}}",
      "x" = "Error: {e$message}"
    ))
  })

  invisible(rscript)
}
