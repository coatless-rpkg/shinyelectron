#' Build Electron Application
#'
#' Builds a distributable Electron application from a converted Shiny app.
#' Creates platform-specific installers and executables.
#'
#' @param app_dir Character string. Path to the converted Shiny/shinylive application.
#' @param output_dir Character string. Path where the built Electron app will be saved.
#' @param app_name Character string. Name of the application. If NULL, uses the base name of app_dir.
#' @param app_type Character string. Type of application: "r-shinylive", "r-shiny", "py-shinylive", or "py-shiny".
#' @param platform Character vector. Target platforms: "win", "mac", "linux". If NULL, builds for current platform.
#' @param arch Character vector. Target architectures: "x64", "arm64". If NULL, uses current architecture.
#' @param icon Character string. Path to application icon file. Platform-specific format required.
#' @param overwrite Logical. Whether to overwrite existing output directory. Default is FALSE.
#' @param verbose Logical. Whether to display detailed progress information. Default is TRUE.
#'
#' @return Character string. Path to the built Electron application directory.
#'
#' @section Details:
#' This function creates a complete Electron application by:
#' \itemize{
#'   \item Setting up the Electron project structure
#'   \item Copying application files and templates
#'   \item Installing npm dependencies
#'   \item Building platform-specific distributables
#' }
#'
#' @examples
#' \dontrun{
#' # Build Electron app for current platform
#' build_electron_app(
#'   app_dir = "path/to/shinylive/app",
#'   output_dir = "path/to/electron/build",
#'   app_name = "My Shiny App",
#'   app_type = "r-shinylive"
#' )
#'
#' # Build for multiple platforms
#' build_electron_app(
#'   app_dir = "path/to/app",
#'   output_dir = "path/to/build",
#'   app_name = "My App",
#'   app_type = "r-shinylive",
#'   platform = c("win", "mac", "linux")
#' )
#' }
#'
#' @export
build_electron_app <- function(app_dir, output_dir, app_name = NULL, app_type = "r-shinylive",
                               platform = NULL, arch = NULL, icon = NULL,
                               overwrite = FALSE, verbose = TRUE) {

  # Validate inputs
  validate_directory_exists(app_dir, "Application directory")
  validate_app_type(app_type)

  if (is.null(app_name)) {
    app_name <- basename(app_dir)
  }
  validate_app_name(app_name)

  if (verbose) {
    cli::cli_h1("Building Electron application")
    cli::cli_alert_info("App: {.val {app_name}}")
    cli::cli_alert_info("Type: {.val {app_type}}")
    cli::cli_alert_info("Source: {.path {app_dir}}")
    cli::cli_alert_info("Output: {.path {output_dir}}")
  }

  # Set up platform and architecture defaults
  if (is.null(platform)) {
    platform <- detect_current_platform()
  }
  if (is.null(arch)) {
    arch <- detect_current_arch()
  }

  validate_platform(platform)
  validate_arch(arch)

  if (verbose) {
    cli::cli_alert_info("Platform(s): {.val {platform}}")
    cli::cli_alert_info("Architecture(s): {.val {arch}}")
  }

  # Check if output directory exists
  if (fs::dir_exists(output_dir)) {
    if (!overwrite) {
      cli::cli_abort(c(
        "Output directory already exists: {.path {output_dir}}",
        "i" = "Use {.code overwrite = TRUE} to overwrite existing directory"
      ))
    } else {
      if (verbose) cli::cli_alert_warning("Overwriting existing directory: {.path {output_dir}}")
      unlink(output_dir, recursive = TRUE)
    }
  }

  # Create output directory
  fs::dir_create(output_dir, recurse = TRUE)

  # Validate npm/node availability
  validate_node_npm()

  if (verbose) {
    pb <- cli::cli_progress_bar("Building Electron app", total = 6)
  }

  tryCatch({
    # Step 1: Setup Electron project structure
    if (verbose) cli::cli_progress_update(id = pb, set = 1)
    setup_electron_project(output_dir, app_name, app_type, verbose = verbose)

    # Step 2: Copy application files
    if (verbose) cli::cli_progress_update(id = pb, set = 2)
    copy_app_files(app_dir, output_dir, app_type, verbose = verbose)

    # Step 3: Copy and process templates
    if (verbose) cli::cli_progress_update(id = pb, set = 3)
    process_templates(output_dir, app_name, app_type, icon, verbose = verbose)

    # Step 4: Install npm dependencies
    if (verbose) cli::cli_progress_update(id = pb, set = 4)
    install_npm_dependencies(output_dir, verbose = verbose)

    # Step 5: Build for target platforms
    if (verbose) cli::cli_progress_update(id = pb, set = 5)
    build_for_platforms(output_dir, platform, arch, verbose = verbose)

    # Step 6: Validate build output
    if (verbose) cli::cli_progress_update(id = pb, set = 6)
    validate_build_output(output_dir, platform)

    if (verbose) {
      cli::cli_progress_done(id = pb)
      cli::cli_alert_success("Successfully built Electron app: {.path {output_dir}}")
    }

    return(fs::path_abs(output_dir))

  }, error = function(e) {
    cli::cli_abort(c(
      "Failed to build Electron application",
      "x" = "Error: {e$message}"
    ))
  })
}
