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
#' @param field Character. Where the name came from, for the error message:
#'   `"app_name"` for the argument, or `"app.name"` for the config key.
#' @keywords internal
validate_app_name <- function(app_name, field = "app_name") {
  hint <- if (identical(field, "app.name")) {
    c("i" = "Edit {.field app.name} in {.file _shinyelectron.yml}, quoting the name if YAML would read it as something else, as in {.code name: \"Yes\"}.")
  }
  if (!is.character(app_name) || length(app_name) != 1 || is.na(app_name)) {
    cli::cli_abort(c("{.field {field}} must be a single character string", hint))
  }
  if (nchar(app_name) == 0) {
    cli::cli_abort(c("{.field {field}} cannot be empty", hint))
  }
  # npm package names have a 214-character limit
  if (nchar(app_name) > 200) {
    cli::cli_abort(c(
      "{.field {field}} is too long ({nchar(app_name)} characters)",
      "i" = "Maximum 200 characters (npm limit is 214, slug adds overhead)",
      hint
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
#' On macOS, electron-builder notarizes with the first kind of credentials it
#' finds in the environment: an Apple ID (`APPLE_ID` and
#' `APPLE_APP_SPECIFIC_PASSWORD`, plus a team ID from `APPLE_TEAM_ID` or
#' `signing.mac.team_id`), an App Store Connect API key (`APPLE_API_KEY`,
#' `APPLE_API_KEY_ID` and `APPLE_API_ISSUER`), or a `notarytool` keychain
#' profile (`APPLE_KEYCHAIN_PROFILE`).
#'
#' @param config List. The effective configuration.
#' @param platform Character string. Target platform ("mac", "win", "linux").
#' @param sign Logical. Whether the build is signed. [export()] and
#'   [app_check()] pass the value their `sign` argument resolves to, which
#'   can turn signing on when `signing.sign` is off. Defaults to
#'   `signing.sign`.
#' @keywords internal
validate_signing_config <- function(config, platform = NULL,
                                    sign = isTRUE(config$signing$sign)) {
  if (!isTRUE(sign)) {
    return(invisible(NULL))
  }

  signing <- config$signing %||% SHINYELECTRON_DEFAULTS$signing
  platform <- platform %||% detect_current_platform()

  if (platform == "mac") {
    # Mirror electron-builder's notarization lookup. It uses the first kind of
    # credentials that has any variable set and stops the build when that set
    # is incomplete; with none set, it skips notarization. The team ID may
    # also come from signing.mac.team_id, which build_for_platforms() passes
    # on as APPLE_TEAM_ID.
    is_set <- function(vars) nzchar(Sys.getenv(vars))
    apple_id_vars <- c("APPLE_ID", "APPLE_APP_SPECIFIC_PASSWORD")
    api_key_vars <- c("APPLE_API_KEY", "APPLE_API_KEY_ID", "APPLE_API_ISSUER")

    if (any(is_set(apple_id_vars))) {
      missing <- apple_id_vars[!is_set(apple_id_vars)]
      if (length(missing) > 0) {
        cli::cli_warn(c(
          "macOS: {.envvar {missing}} is not set, so notarization will fail.",
          "i" = "Notarizing with an Apple ID needs both {.envvar APPLE_ID} and {.envvar APPLE_APP_SPECIFIC_PASSWORD}."
        ))
      }
      if (!is_set("APPLE_TEAM_ID") && !is_nonempty_string(signing$mac$team_id)) {
        cli::cli_warn(c(
          "macOS: no Apple team ID, so notarization will fail.",
          "i" = "Set {.field signing.mac.team_id} or {.envvar APPLE_TEAM_ID}."
        ))
      }
    } else if (any(is_set(api_key_vars))) {
      missing <- api_key_vars[!is_set(api_key_vars)]
      if (length(missing) > 0) {
        cli::cli_warn(c(
          "macOS: {.envvar {missing}} {?is/are} not set, so notarization will fail.",
          "i" = "Notarizing with an API key needs {.envvar APPLE_API_KEY}, {.envvar APPLE_API_KEY_ID}, and {.envvar APPLE_API_ISSUER}."
        ))
      }
    } else if (!is_set("APPLE_KEYCHAIN_PROFILE")) {
      cli::cli_warn(c(
        "macOS: no notarization credentials, so notarization will be skipped.",
        "i" = "Set {.envvar APPLE_ID}, {.envvar APPLE_APP_SPECIFIC_PASSWORD}, and a team ID in {.field signing.mac.team_id} or {.envvar APPLE_TEAM_ID}; or set {.envvar APPLE_API_KEY}, {.envvar APPLE_API_KEY_ID}, and {.envvar APPLE_API_ISSUER}."
      ))
    }

    identity <- signing$mac$identity
    if (is.null(identity)) {
      cli::cli_warn("macOS: No signing identity configured -- electron-builder will attempt keychain auto-discovery")
    }
  }

  if (platform == "win") {
    # Mirror electron-builder's Windows lookup: the certificate comes from
    # signing.win.certificate_file, then WIN_CSC_LINK, then CSC_LINK, and
    # the password from WIN_CSC_KEY_PASSWORD, then CSC_KEY_PASSWORD. Like
    # electron-builder, stop at the first variable that is set, even when it
    # is empty.
    first_set <- function(vars) {
      set <- vars[!is.na(Sys.getenv(vars, unset = NA))]
      if (length(set) > 0) set[[1]] else NULL
    }

    cert_var <- NULL
    cert <- signing$win$certificate_file
    if (is.null(cert)) {
      cert_var <- first_set(c("WIN_CSC_LINK", "CSC_LINK"))
      cert <- if (is.null(cert_var)) "" else Sys.getenv(cert_var)
    }

    if (!nzchar(cert)) {
      if (is.null(cert_var)) {
        cli::cli_warn(c(
          "Windows: no signing certificate, so Windows builds will be unsigned.",
          "i" = "Set {.field signing.win.certificate_file}, {.envvar WIN_CSC_LINK}, or {.envvar CSC_LINK}."
        ))
      } else {
        cli::cli_warn(c(
          "Windows: {.envvar {cert_var}} is set but empty, so Windows builds will be unsigned.",
          "i" = "electron-builder reads {.envvar WIN_CSC_LINK} before {.envvar CSC_LINK} and stops at the first one that is set."
        ))
      }
    } else {
      pw_var <- first_set(c("WIN_CSC_KEY_PASSWORD", "CSC_KEY_PASSWORD"))
      if (is.null(pw_var)) {
        cli::cli_warn(c(
          "Windows: no certificate password, so signing may fail.",
          "i" = "Set {.envvar WIN_CSC_KEY_PASSWORD} or {.envvar CSC_KEY_PASSWORD}."
        ))
      } else if (!nzchar(Sys.getenv(pw_var))) {
        cli::cli_warn(c(
          "Windows: {.envvar {pw_var}} is set but empty, so signing may fail.",
          "i" = "electron-builder reads {.envvar WIN_CSC_KEY_PASSWORD} before {.envvar CSC_KEY_PASSWORD} and stops at the first one that is set."
        ))
      }
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
#' Checks that the icon file exists and that each target platform can use
#' it, for its format and for the size of its image (see
#' [icon_platforms()]). A platform that cannot gets the default Electron
#' icon, so this warns rather than errors and the build continues.
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

  platform <- platform %||% detect_current_platform()
  # app_check() passes on a platform argument that it reports as invalid.
  platform <- intersect(platform, SHINYELECTRON_DEFAULTS$valid_platforms)
  # generate_package_json() gives these platforms no icon.
  min_size <- icon_min_size(icon)
  unsupported <- setdiff(platform, names(min_size))
  if (length(unsupported) > 0) {
    cli::cli_warn(c(
      "The icon {.path {icon}} cannot be used for {.val {unsupported}}.",
      "i" = "electron-builder makes the icon for every platform from a PNG (1024x1024 or larger) or an {.file .icns} file, and uses an {.file .ico} file only for Windows.",
      "i" = "The {.val {unsupported}} build{?s} will show the default Electron icon."
    ), class = "shinyelectron_icon_unsupported")
  }
  too_small <- setdiff(intersect(platform, names(min_size)), icon_platforms(icon))
  if (length(too_small) > 0) {
    os <- c(win = "Windows", mac = "macOS", linux = "Linux")[too_small]
    needs <- paste0(min_size[too_small], "x", min_size[too_small],
                    " pixels for ", os)
    cli::cli_warn(c(
      "The icon {.path {icon}} is too small for {.val {too_small}}.",
      "i" = "electron-builder needs an image of at least {needs}.",
      "i" = "The {.val {too_small}} build{?s} will show the default Electron icon."
    ), class = c("shinyelectron_icon_too_small", "shinyelectron_icon_unsupported"))
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
