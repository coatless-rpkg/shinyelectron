#' Run Electron Application for Testing
#'
#' Launches a previously exported Electron application for testing and debugging
#' without building distributable packages. Pass the `electron-app` directory
#' from a prior `export()` call.
#'
#' @param app_dir Character string. Path to the Electron application directory
#'   (the `electron-app` subdirectory from `export()`).
#' @param port Integer. Port number for the development server. Default is 3000.
#' @param open_devtools Logical. Whether to open Chromium DevTools automatically. Default is TRUE.
#' @param verbose Logical. Whether to display detailed progress information. Default is TRUE.
#'
#' @return Invisibly returns the process object for the running application.
#'
#' @section Details:
#' This function starts the Electron application for testing, which:
#' \itemize{
#'   \item Opens the application in an Electron window
#'   \item Optionally opens Chromium DevTools for debugging
#'   \item Does NOT build distributable packages (use `export(build = TRUE)` for that)
#' }
#'
#' @examples
#' \dontrun{
#' # Run Electron app in development mode
#' run_electron_app("path/to/electron/app")
#'
#' # Run with custom port and no dev tools
#' run_electron_app(
#'   app_dir = "path/to/app",
#'   port = 8080,
#'   open_devtools = FALSE
#' )
#' }
#'
#' @export
run_electron_app <- function(app_dir, port = 3000, open_devtools = TRUE, verbose = TRUE) {

  # Validate inputs
  validate_directory_exists(app_dir, "Electron application directory")
  validate_electron_project(app_dir)
  validate_port(port)

  if (verbose) {
    cli::cli_h1("Running Electron application in development mode")
    cli::cli_alert_info("App directory: {.path {app_dir}}")
    cli::cli_alert_info("Port: {.val {port}}")
    cli::cli_alert_info("Developer tools: {.val {if(open_devtools) 'enabled' else 'disabled'}}")
  }

  # Validate npm/node availability
  validate_node_npm()

  # Check if package.json exists and has necessary scripts
  package_json_path <- fs::path(app_dir, "package.json")
  if (!fs::file_exists(package_json_path)) {
    cli::cli_abort(c(
      "No {.file package.json} found in {.path {app_dir}}",
      "i" = "Run {.code export()} first to build the Electron project"
    ))
  }

  package_json <- jsonlite::fromJSON(package_json_path, simplifyVector = FALSE)
  if (is.null(package_json$scripts$electron)) {
    cli::cli_abort(c(
      "No {.val electron} script in {.file {package_json_path}}",
      "i" = "Add one under {.field scripts}: {.code \"electron\": \"electron .\"}",
      "i" = "Or re-run {.code export()} to regenerate {.file package.json}"
    ))
  }

  # Set environment variables
  old_env <- set_dev_environment(port, open_devtools)
  on.exit(restore_environment(old_env))

  if (verbose) {
    cli::cli_alert_info("Starting Electron application...")
    cli::cli_alert_info("Press Ctrl+C to stop the application")
  }

  tryCatch({
    result <- processx::run(
      command = get_npm_command(),
      args = c("run", "electron"),
      wd = app_dir,
      echo = verbose,
      echo_cmd = verbose,
      spinner = verbose,
      error_on_status = FALSE
    )

    if (result$status != 0) {
      cli::cli_abort(c(
        "Failed to start Electron application",
        "x" = "Exit code: {result$status}",
        "i" = "stderr: {result$stderr}"
      ))
    }

    if (verbose) {
      cli::cli_alert_success("Electron application started successfully")
    }

    return(invisible(result))

  }, error = function(e) {
    cli::cli_abort(c(
      "Failed to run Electron application",
      "x" = "Error: {e$message}"
    ))
  }, interrupt = function(int) {
    if (verbose) {
      cli::cli_alert_info("Stopping Electron application...")
    }
    return(invisible(NULL))
  })
}
