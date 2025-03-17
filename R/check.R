#' Check directory existence and create destination directory if needed
#'
#' Validates that the source application directory exists and creates the 
#' destination directory if it doesn't exist.
#'
#' @param appdir Character string. Path to the directory containing the Shiny application.
#' @param destdir Character string. Path to the destination directory where the Electron app will be created.
#'
#' @return Invisibly returns TRUE if successful.
#' 
#' @section Error Handling:
#' Throws an error if the specified app directory does not exist.
#' 
#' @keywords internal
check_directories <- function(appdir, destdir) {
  if (!dir.exists(appdir)) {
    cli::cli_abort("The specified app directory does not exist: {.path {appdir}}")
  }
  if (!dir.exists(destdir)) {
    cli::cli_alert_info("Creating destination directory: {.path {destdir}}")
    dir.create(destdir, recursive = TRUE)
  }
  invisible(TRUE)
}

#' Validate application name
#'
#' Checks if the provided application name is valid. If no name is provided,
#' uses the base name of the app directory. Validates that the name is a non-empty
#' character string containing only allowed characters.
#'
#' @param app_name Character string or NULL. Name of the application. If NULL, 
#'        the base name of appdir will be used.
#' @param appdir Character string. Path to the directory containing the Shiny application.
#'
#' @return Invisibly returns TRUE if the name is valid.
#' 
#' @section Error Handling:
#' Throws an error if app_name is not a single character string, is empty, or contains invalid characters.
#' 
#' @keywords internal
check_app_name <- function(app_name, appdir) {
  if (is.null(app_name)) {
    app_name <- basename(appdir)
  }
  if (!is.character(app_name) || length(app_name) != 1) {
    cli::cli_abort("app_name must be a single character string")
  }
  if (nchar(app_name) == 0) {
    cli::cli_abort("app_name cannot be empty")
  }
  if (grepl("[^[:alnum:]._-]", app_name)) {
    cli::cli_abort("app_name can only contain alphanumeric characters, dots, underscores, and hyphens")
  }
  invisible(TRUE)
}

#' Validate target platform
#'
#' Checks if the specified platform is valid. If no platform is provided,
#' uses the current system platform. Supported platforms are Windows, macOS, and Linux.
#'
#' @param platform Character string or NULL. Target platform: "win", "mac", or "linux".
#'        If NULL, the current system platform will be used.
#'
#' @return Invisibly returns TRUE if the platform is valid.
#' 
#' @section Error Handling:
#' Throws an error if an invalid platform is specified.
#' 
#' @keywords internal
check_platform <- function(platform) {
  valid_platforms <- c("win", "mac", "linux")
  current_platform <- switch(Sys.info()[["sysname"]],
                             "Windows" = "win",
                             "Darwin" = "mac",
                             "Linux" = "linux"
  )
  platform <- platform %||% current_platform
  if (!is.null(platform) && !(platform %in% valid_platforms)) {
    cli::cli_abort("Invalid platform. Must be one of: {.val {valid_platforms}}")
  }
  invisible(TRUE)
}

#' Validate target architecture
#'
#' Checks if the specified architecture is valid. If no architecture is provided,
#' uses the current system architecture. Supported architectures are x64 and arm64.
#'
#' @param arch Character string or NULL. Target architecture: "x64" or "arm64".
#'        If NULL, the current system architecture will be used.
#'
#' @return Invisibly returns TRUE if the architecture is valid.
#' 
#' @section Error Handling:
#' Throws an error if an invalid architecture is specified.
#' 
#' @keywords internal
check_arch <- function(arch) {
  valid_arch <- c("x64", "arm64")
  current_arch <- if (grepl("arm|aarch", Sys.info()[["machine"]], ignore.case = TRUE)) "arm64" else "x64"
  arch <- arch %||% current_arch
  if (!is.null(arch) && !(arch %in% valid_arch)) {
    cli::cli_abort("Invalid architecture. Must be one of: {.val {valid_arch}}")
  }
  invisible(TRUE)
}

#' Validate R version format
#'
#' Checks if the specified R version has a valid format (X.Y.Z). If no version is provided,
#' uses the current R version. This check is only performed if R is being bundled with the application.
#'
#' @param r_version Character string or NULL. Version of R to bundle (format: X.Y.Z).
#'        If NULL, the current R version will be used.
#' @param include_r Logical. Whether R is being bundled with the application.
#'
#' @return Invisibly returns TRUE if the R version format is valid or if R is not included.
#' 
#' @section Error Handling:
#' Throws an error if an invalid R version format is specified when include_r is TRUE.
#' 
#' @keywords internal
check_r_version <- function(r_version, include_r) {
  if (!include_r) {
    return(invisible(TRUE))
  }
  r_version <- r_version %||% paste0(R.version$major, ".", R.version$minor)
  if (!grepl("^[0-9]+\\.[0-9]+\\.[0-9]+$", r_version)) {
    cli::cli_abort("Invalid R version format. Expected format: X.Y.Z")
  }
  invisible(TRUE)
}

#' Validate application icon file
#'
#' Checks if the specified icon file exists and has the correct format for the target platform.
#' Windows requires .ico files, macOS requires .icns files, and Linux requires .png files.
#'
#' @param icon Character string or NULL. Path to the application icon file.
#'        If NULL, a default icon will be used.
#' @param platform Character string. Target platform determining the required icon format:
#'        "win" (Windows), "mac" (macOS), or "linux" (Linux).
#'
#' @return Invisibly returns TRUE if the icon is valid or if no custom icon is specified.
#' 
#' @section Error Handling:
#' Throws an error if the icon file does not exist or has an incorrect format for the target platform.
#' 
#' @keywords internal
check_icon <- function(icon, platform) {
  if (is.null(icon)) {
    return(invisible(TRUE))
  }
  if (!file.exists(icon)) {
    cli::cli_abort("Icon file does not exist: {.path {icon}}")
  }
  icon_ext <- tools::file_ext(icon)
  expected_ext <- if (platform == "win") "ico" else if (platform == "mac") "icns" else "png"
  if (icon_ext != expected_ext) {
    cli::cli_abort("Invalid icon format for {platform}. Expected .{expected_ext}, got .{icon_ext}")
  }
  invisible(TRUE)
}
