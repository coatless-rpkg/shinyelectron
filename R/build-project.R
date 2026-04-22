#' Setup Electron project structure
#'
#' @param output_dir Character path to output directory
#' @param app_name Character application name
#' @param app_type Character application type
#' @param verbose Logical whether to show progress
#' @keywords internal
setup_electron_project <- function(output_dir, app_name, app_type, verbose = TRUE) {
  if (verbose) {
    cli::cli_alert_info("Setting up Electron project structure...")
  }

  # Create necessary directories
  dirs_to_create <- c("src", "assets", "build")
  for (dir in dirs_to_create) {
    fs::dir_create(fs::path(output_dir, dir), recurse = TRUE)
  }

  if (verbose) {
    cli::cli_alert_success("Created project structure")
  }
}
#' Copy application files to Electron project
#'
#' @param app_dir Character source app directory
#' @param output_dir Character destination directory
#' @param app_type Character application type
#' @param verbose Logical whether to show progress
#' @keywords internal
copy_app_files <- function(app_dir, output_dir, app_type, verbose = TRUE) {
  if (verbose) {
    cli::cli_alert_info("Copying application files...")
  }

  dest_app_dir <- fs::path(output_dir, "src", "app")
  copy_dir_contents(app_dir, dest_app_dir)

  # Sanity check: for native Shiny apps, confirm the entrypoint made it across.
  # Catches copy-layout bugs at build time rather than at runtime inside Electron.
  entry_files <- switch(app_type,
    "r-shiny" = c("app.R", "server.R", "ui.R"),
    "py-shiny" = "app.py",
    NULL  # shinylive types validate their own output
  )
  if (!is.null(entry_files)) {
    found <- any(fs::file_exists(fs::path(dest_app_dir, entry_files)))
    if (!found) {
      cli::cli_abort(c(
        "Application files were copied but no Shiny entrypoint was found",
        "i" = "Expected one of: {paste(entry_files, collapse = ', ')}",
        "x" = "In: {.path {dest_app_dir}}"
      ))
    }
  }

  if (verbose) {
    cli::cli_alert_success("Copied application files")
  }
}
