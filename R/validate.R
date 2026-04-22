#' Validate that a directory exists
#'
#' @param dir Character path to directory
#' @param name Character descriptive name for error messages
#' @keywords internal
validate_directory_exists <- function(dir, name = "Directory") {
  if (!fs::dir_exists(dir)) {
    cli::cli_abort("{name} does not exist: {.path {dir}}")
  }
}

#' Validate application name
#'
#' @param app_name Character application name
#' @keywords internal
validate_app_name <- function(app_name) {
  if (!is.character(app_name) || length(app_name) != 1) {
    cli::cli_abort("app_name must be a single character string")
  }
  if (nchar(app_name) == 0) {
    cli::cli_abort("app_name cannot be empty")
  }
  # npm package names have a 214-character limit
  if (nchar(app_name) > 200) {
    cli::cli_abort(c(
      "app_name is too long ({nchar(app_name)} characters)",
      "i" = "Maximum 200 characters (npm limit is 214, slug adds overhead)"
    ))
  }
  # Display names can contain spaces and special characters.
  # The path-safe slug is derived separately via slugify().
}

#' Validate target platform
#'
#' @param platform Character vector of platforms
#' @keywords internal
validate_platform <- function(platform) {
  valid_platforms <- SHINYELECTRON_DEFAULTS$valid_platforms
  invalid <- platform[!platform %in% valid_platforms]
  if (length(invalid) > 0) {
    cli::cli_abort(c(
      "Invalid platform(s): {.val {invalid}}",
      "i" = "Must be one of: {.val {valid_platforms}}",
      "i" = "Current platform: {.val {detect_current_platform()}}"
    ))
  }
}

#' Validate target architecture
#'
#' @param arch Character vector of architectures
#' @keywords internal
validate_arch <- function(arch) {
  valid_arch <- SHINYELECTRON_DEFAULTS$valid_architectures
  invalid <- arch[!arch %in% valid_arch]
  if (length(invalid) > 0) {
    cli::cli_abort(c(
      "Invalid architecture(s): {.val {invalid}}",
      "i" = "Must be one of: {.val {valid_arch}}",
      "i" = "Current architecture: {.val {detect_current_arch()}}"
    ))
  }
}

#' Validate port number
#'
#' @param port Integer port number
#' @keywords internal
validate_port <- function(port) {
  if (!is.numeric(port) || length(port) != 1 || port < 1 || port > 65535) {
    cli::cli_abort(c(
      "Invalid port number: {.val {port}}",
      "i" = "Port must be a single integer between 1 and 65535",
      "i" = "Default port: {.val {SHINYELECTRON_DEFAULTS$server_port}}"
    ))
  }
}

#' Validate Electron project structure
#'
#' @param app_dir Character path to Electron app directory
#' @keywords internal
validate_electron_project <- function(app_dir) {
  # Check for package.json
  package_json <- fs::path(app_dir, "package.json")
  if (!fs::file_exists(package_json)) {
    cli::cli_abort("Not a valid Electron project: no package.json found in {.path {app_dir}}")
  }

  # Check for main.js or src/main.js
  main_js <- fs::path(app_dir, "main.js")
  src_main_js <- fs::path(app_dir, "src", "main.js")

  if (!fs::file_exists(main_js) && !fs::file_exists(src_main_js)) {
    cli::cli_abort("Not a valid Electron project: no main.js found in {.path {app_dir}}")
  }
}

#' Validate build output
#'
#' @param output_dir Character Electron project directory
#' @param platform Character vector of target platforms
#' @keywords internal
validate_build_output <- function(output_dir, platform) {
  dist_dir <- fs::path(output_dir, "dist")

  if (!fs::dir_exists(dist_dir)) {
    cli::cli_alert_warning("No dist directory found - build may have failed")
    return()
  }

  # Check if we have output for each platform
  dist_contents <- list.files(dist_dir)

  for (p in platform) {
    platform_files <- dist_contents[grepl(p, dist_contents, ignore.case = TRUE)]
    if (length(platform_files) == 0) {
      cli::cli_alert_warning("No build output found for platform: {p}")
    }
  }
}

#' Validate code signing configuration
#'
#' Checks that required credentials are available when signing is enabled.
#' Issues warnings (not errors) for missing credentials so the build can
#' continue -- electron-builder will handle the actual failure.
#'
#' @param config List. The effective configuration.
#' @param platform Character string. Target platform ("mac", "win", "linux").
#' @keywords internal
validate_signing_config <- function(config, platform = NULL) {
  signing <- config$signing %||% SHINYELECTRON_DEFAULTS$signing

  if (!isTRUE(signing$sign)) {
    return(invisible(NULL))
  }

  platform <- platform %||% detect_current_platform()

  if (platform == "mac") {
    team_id <- signing$mac$team_id %||% Sys.getenv("APPLE_TEAM_ID", "")
    if (!nzchar(team_id)) {
      cli::cli_warn("macOS: {.envvar APPLE_TEAM_ID} not set and {.field signing.mac.team_id} not configured -- notarization will be skipped")
    }

    if (isTRUE(signing$mac$notarize)) {
      apple_id <- Sys.getenv("APPLE_ID", "")
      apple_pw <- Sys.getenv("APPLE_APP_SPECIFIC_PASSWORD", "")
      if (!nzchar(apple_id) || !nzchar(apple_pw)) {
        cli::cli_warn("macOS: {.envvar APPLE_ID} and/or {.envvar APPLE_APP_SPECIFIC_PASSWORD} not set -- notarization will fail")
      }
    }

    identity <- signing$mac$identity
    if (is.null(identity)) {
      cli::cli_warn("macOS: No signing identity configured -- electron-builder will attempt keychain auto-discovery")
    }
  }

  if (platform == "win") {
    cert_file <- signing$win$certificate_file %||% Sys.getenv("CSC_LINK", "")
    if (!nzchar(cert_file)) {
      cli::cli_warn("Windows: {.envvar CSC_LINK} not set and {.field signing.win.certificate_file} not configured -- Windows builds will be unsigned")
    }

    cert_pw <- Sys.getenv("CSC_KEY_PASSWORD", "")
    if (nzchar(cert_file) && !nzchar(cert_pw)) {
      cli::cli_warn("Windows: {.envvar CSC_KEY_PASSWORD} not set -- signing may fail")
    }
  }

  if (platform == "linux") {
    if (isTRUE(signing$linux$gpg_sign)) {
      gpg_key <- Sys.getenv("GPG_KEY", "")
      if (!nzchar(gpg_key)) {
        cli::cli_warn("Linux: {.envvar GPG_KEY} not set -- GPG signing will fail")
      }
    }
  }

  invisible(NULL)
}

#' Validate icon file for target platform
#'
#' Checks that the icon file exists and has the correct format for the
#' target platform. Issues warnings (not errors) for format mismatches
#' so the build can continue.
#'
#' @param icon Character path to icon file.
#' @param platform Character vector of target platforms.
#' @keywords internal
validate_icon <- function(icon, platform = NULL) {
  if (is.null(icon)) return(invisible(NULL))

  if (!file.exists(icon)) {
    cli::cli_abort(c(
      "Icon file not found: {.path {icon}}",
      "i" = "Provide a valid path to an icon file"
    ))
  }

  ext <- tolower(tools::file_ext(icon))
  platform <- platform %||% detect_current_platform()

  for (p in platform) {
    expected <- switch(p,
      "mac" = "icns",
      "win" = "ico",
      "linux" = "png",
      NULL
    )
    if (!is.null(expected) && ext != expected) {
      cli::cli_warn(c(
        "Icon format mismatch for {.val {p}} platform",
        "x" = "Got {.file .{ext}} but {.val {p}} expects {.file .{expected}}",
        "i" = "electron-builder may fail or use a default icon"
      ))
    }
  }

  # Check reasonable file size (icons shouldn't be > 10MB)
  size <- file.info(icon)$size
  if (!is.na(size) && size > 10 * 1024 * 1024) {
    cli::cli_warn(c(
      "Icon file is unusually large ({.val {round(size / 1024 / 1024, 1)}} MB)",
      "i" = "Consider using a smaller icon file"
    ))
  }

  invisible(icon)
}
