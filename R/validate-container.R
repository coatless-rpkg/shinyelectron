#' Validate a container engine is available
#'
#' Checks that Docker or Podman is installed and can be executed.
#'
#' @param preference Character string or NULL. Preferred engine.
#' @return Invisible character string with the engine name.
#' @keywords internal
validate_container_available <- function(preference = NULL) {
  engine <- detect_container_engine(preference)

  if (is.null(engine)) {
    cli::cli_abort(c(
      "Neither Docker nor Podman was found on the system",
      "i" = "Install Docker: {.url https://docs.docker.com/get-docker/}",
      "i" = "Install Podman: {.url https://podman.io/getting-started/installation}"
    ))
  }

  tryCatch({
    result <- processx::run(engine, c("info"),
                            error_on_status = FALSE, timeout = 15)
    if (result$status != 0) {
      cli::cli_abort(c(
        "{.strong {engine}} is installed but not running",
        "i" = "Start the {engine} daemon and try again",
        "x" = "Error: {result$stderr}"
      ))
    }
  }, error = function(e) {
    cli::cli_abort(c(
      "{.strong {engine}} was found but could not be executed",
      "x" = "Error: {e$message}"
    ))
  })

  invisible(engine)
}
