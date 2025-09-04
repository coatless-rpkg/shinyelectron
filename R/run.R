#' Run Electron Application in Development Mode
#'
#' Runs the Electron application in development mode for testing and debugging.
#' This allows you to test your application before building distributable packages.
#'
#' @param app_dir Character string. Path to the Electron application directory.
#' @param port Integer. Port number for the development server. Default is 3000.
#' @param open_devtools Logical. Whether to open developer tools automatically. Default is TRUE.
#' @param verbose Logical. Whether to display detailed progress information. Default is TRUE.
#'
#' @return Invisibly returns the process object for the running application.
#'
#' @section Details:
#' This function starts the Electron application in development mode, which:
#' \itemize{
#'   \item Starts a local development server
#'   \item Opens the application in an Electron window
#'   \item Enables hot reloading for development
#'   \item Provides access to developer tools for debugging
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
    cli::cli_abort("No package.json found in: {.path {app_dir}}")
  }

  package_json <- jsonlite::fromJSON(package_json_path, simplifyVector = FALSE)
  if (is.null(package_json$scripts$electron)) {
    cli::cli_abort("No 'electron' script found in package.json")
  }

  # Set environment variables
  old_env <- set_dev_environment(port, open_devtools)
  on.exit(restore_environment(old_env))

  if (verbose) {
    cli::cli_alert_info("Starting Electron application...")
    cli::cli_alert_info("Press Ctrl+C to stop the application")
  }

  tryCatch({
    # Change to app directory
    old_wd <- getwd()
    setwd(app_dir)
    on.exit(setwd(old_wd), add = TRUE)

    # Run npm electron command
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
