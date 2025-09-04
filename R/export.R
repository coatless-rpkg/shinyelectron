#' Export Shiny Application as Electron Desktop Application
#'
#' Main entry point function that wraps the conversion, building, and optionally
#' running of a Shiny application as an Electron desktop application.
#'
#' @param appdir Character string. Path to the directory containing the Shiny application.
#' @param destdir Character string. Path to the destination directory where the Electron app will be created.
#' @param app_name Character string. Name of the application. If NULL, uses the base name of appdir.
#' @param app_type Character string. Type of application: "r-shinylive" (default), "r-shiny", "py-shinylive", or "py-shiny".
#' @param platform Character vector. Target platforms: "win", "mac", "linux". If NULL, builds for current platform.
#' @param arch Character vector. Target architectures: "x64", "arm64". If NULL, uses current architecture.
#' @param icon Character string. Path to application icon file. Platform-specific format required.
#' @param overwrite Logical. Whether to overwrite existing output directory. Default is FALSE.
#' @param build Logical. Whether to build distributable packages. Default is TRUE.
#' @param run_after Logical. Whether to run the application in development mode after export. Default is FALSE.
#' @param open_after Logical. Whether to open the generated project directory after export. Default is FALSE.
#' @param verbose Logical. Whether to display detailed progress information. Default is TRUE.
#'
#' @return List containing paths to the converted app and built Electron app (if built).
#'
#' @section Details:
#' This is the main function of the package that orchestrates the entire process:
#' \itemize{
#'   \item Validates the input Shiny application
#'   \item Converts the Shiny app to the specified format (shinylive by default)
#'   \item Sets up the Electron project structure
#'   \item Optionally builds distributable packages
#'   \item Optionally runs the application for testing
#' }
#'
#' @section Supported Application Types:
#' \itemize{
#'   \item \code{r-shinylive}: R Shiny app converted to run entirely in browser (recommended)
#'   \item \code{r-shiny}: R Shiny app with embedded R runtime
#'   \item \code{py-shinylive}: Python Shiny app converted to run entirely in browser
#'   \item \code{py-shiny}: Python Shiny app with embedded Python runtime
#' }
#'
#' @examples
#' \dontrun{
#' # Basic export to shinylive Electron app
#' export(
#'   appdir = "path/to/shiny/app",
#'   destdir = "path/to/electron/output"
#' )
#'
#' # Export with custom settings
#' export(
#'   appdir = "path/to/shiny/app",
#'   destdir = "path/to/output",
#'   app_name = "My Amazing App",
#'   app_type = "r-shinylive",
#'   platform = c("win", "mac"),
#'   icon = "path/to/icon.ico",
#'   overwrite = TRUE,
#'   run_after = TRUE
#' )
#'
#' # Export regular Shiny app (with R runtime)
#' export(
#'   appdir = "path/to/shiny/app",
#'   destdir = "path/to/output",
#'   app_type = "r-shiny"
#' )
#' }
#'
#' @export
export <- function(appdir, destdir, app_name = NULL, app_type = "r-shinylive",
                   platform = NULL, arch = NULL, icon = NULL,
                   overwrite = FALSE, build = TRUE, run_after = FALSE,
                   open_after = FALSE, verbose = TRUE) {

  # Validate inputs
  validate_directory_exists(appdir, "Application directory")
  validate_app_type(app_type)

  if (is.null(app_name)) {
    app_name <- basename(appdir)
  }
  validate_app_name(app_name)

  if (verbose) {
    cli::cli_h1("Exporting Shiny application to Electron")
    cli::cli_alert_info("Application: {.val {app_name}}")
    cli::cli_alert_info("Type: {.val {app_type}}")
    cli::cli_alert_info("Source: {.path {appdir}}")
    cli::cli_alert_info("Destination: {.path {destdir}}")
  }

  # Create destination directory
  if (fs::dir_exists(destdir)) {
    if (!overwrite) {
      cli::cli_abort(c(
        "Destination directory already exists: {.path {destdir}}",
        "i" = "Use {.code overwrite = TRUE} to overwrite existing directory"
      ))
    } else {
      if (verbose) cli::cli_alert_warning("Overwriting existing directory: {.path {destdir}}")
      unlink(destdir, recursive = TRUE)
    }
  }

  fs::dir_create(destdir, recurse = TRUE)

  result <- list()

  tryCatch({
    # Step 1: Convert application based on type
    converted_app_dir <- NULL

    if (app_type %in% c("r-shinylive", "py-shinylive")) {
      if (verbose) cli::cli_alert_info("Converting to shinylive format...")

      shinylive_dir <- fs::path(destdir, "shinylive-app")

      if (app_type == "r-shinylive") {
        converted_app_dir <- convert_shiny_to_shinylive(
          appdir = appdir,
          output_dir = shinylive_dir,
          overwrite = TRUE,
          verbose = verbose
        )
      } else {
        # For Python shinylive, we'd need to implement py-shinylive conversion
        cli::cli_abort("Python shinylive conversion not yet implemented")
      }

      result$converted_app <- converted_app_dir

    } else {
      # For regular Shiny apps, just copy the source
      if (verbose) cli::cli_alert_info("Preparing application files...")

      app_copy_dir <- fs::path(destdir, "shiny-app")
      fs::dir_copy(appdir, app_copy_dir)
      converted_app_dir <- app_copy_dir
      result$converted_app <- converted_app_dir
    }

    # Step 2: Build Electron application if requested
    if (build) {
      if (verbose) cli::cli_alert_info("Building Electron application...")

      electron_dir <- fs::path(destdir, "electron-app")

      built_app_dir <- build_electron_app(
        app_dir = converted_app_dir,
        output_dir = electron_dir,
        app_name = app_name,
        app_type = app_type,
        platform = platform,
        arch = arch,
        icon = icon,
        overwrite = TRUE,
        verbose = verbose
      )

      result$electron_app <- built_app_dir
    }

    # Step 3: Run application in development mode if requested
    if (run_after && build) {
      if (verbose) cli::cli_alert_info("Starting application in development mode...")

      run_electron_app(
        app_dir = result$electron_app,
        verbose = verbose
      )
    }

    # Step 4: Open output directory if requested
    if (open_after) {
      if (verbose) cli::cli_alert_info("Opening output directory...")
      utils::browseURL(destdir)
    }

    if (verbose) {
      cli::cli_alert_success("Successfully exported Shiny application to Electron!")
      cli::cli_alert_info("Output directory: {.path {destdir}}")

      if (build) {
        cli::cli_alert_info("Electron app: {.path {result$electron_app}}")
        if (fs::dir_exists(fs::path(result$electron_app, "dist"))) {
          cli::cli_alert_info("Distributables: {.path {fs::path(result$electron_app, 'dist')}}")
        }
      }
    }

    return(result)

  }, error = function(e) {
    cli::cli_abort(c(
      "Failed to export Shiny application",
      "x" = "Error: {e$message}"
    ))
  })
}
