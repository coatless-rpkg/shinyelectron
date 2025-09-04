#' Validation functions for shinyelectron package
#'
#' @name validate
#' @keywords internal
NULL

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

#' Validate Shiny application structure
#'
#' @param appdir Character path to Shiny app directory
#' @keywords internal
validate_shiny_app_structure <- function(appdir) {
  # Check for app.R or server.R/ui.R
  app_r <- fs::path(appdir, "app.R")
  server_r <- fs::path(appdir, "server.R")
  ui_r <- fs::path(appdir, "ui.R")

  has_app_r <- fs::file_exists(app_r)
  has_server_ui <- fs::file_exists(server_r) && fs::file_exists(ui_r)

  if (!has_app_r && !has_server_ui) {
    cli::cli_abort(c(
      "Invalid Shiny application structure in: {.path {appdir}}",
      "i" = "Expected either app.R or both server.R and ui.R"
    ))
  }
}

#' Validate shinylive output
#'
#' @param output_dir Character path to shinylive output
#' @keywords internal
validate_shinylive_output <- function(output_dir) {
  # Check for index.html
  index_html <- fs::path(output_dir, "index.html")
  if (!fs::file_exists(index_html)) {
    cli::cli_abort("Shinylive conversion failed: no index.html found in {.path {output_dir}}")
  }

  # Check for shinylive directory
  shinylive_dir <- fs::path(output_dir, "shinylive")
  if (!fs::dir_exists(shinylive_dir)) {
    cli::cli_abort("Shinylive conversion failed: no shinylive directory found in {.path {output_dir}}")
  }
}

#' Validate application type
#'
#' @param app_type Character application type
#' @keywords internal
validate_app_type <- function(app_type) {
  valid_types <- c("r-shinylive", "r-shiny", "py-shinylive", "py-shiny")
  if (!app_type %in% valid_types) {
    cli::cli_abort(c(
      "Invalid app_type: {.val {app_type}}",
      "i" = "Must be one of: {.val {valid_types}}"
    ))
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
  if (grepl("[^[:alnum:]._-]", app_name)) {
    cli::cli_abort("app_name can only contain alphanumeric characters, dots, underscores, and hyphens")
  }
}

#' Validate target platform
#'
#' @param platform Character vector of platforms
#' @keywords internal
validate_platform <- function(platform) {
  valid_platforms <- c("win", "mac", "linux")
  invalid <- platform[!platform %in% valid_platforms]
  if (length(invalid) > 0) {
    cli::cli_abort(c(
      "Invalid platform(s): {.val {invalid}}",
      "i" = "Must be one of: {.val {valid_platforms}}"
    ))
  }
}

#' Validate target architecture
#'
#' @param arch Character vector of architectures
#' @keywords internal
validate_arch <- function(arch) {
  valid_arch <- c("x64", "arm64")
  invalid <- arch[!arch %in% valid_arch]
  if (length(invalid) > 0) {
    cli::cli_abort(c(
      "Invalid architecture(s): {.val {invalid}}",
      "i" = "Must be one of: {.val {valid_arch}}"
    ))
  }
}

#' Validate port number
#'
#' @param port Integer port number
#' @keywords internal
validate_port <- function(port) {
  if (!is.numeric(port) || length(port) != 1 || port < 1 || port > 65535) {
    cli::cli_abort("port must be a single integer between 1 and 65535")
  }
}

#' Validate Node.js and npm availability
#'
#' @keywords internal
validate_node_npm <- function() {
  # Check Node.js
  node_result <- tryCatch({
    processx::run("node", "--version", error_on_status = FALSE)
  }, error = function(e) {
    list(status = 1, stderr = "Node.js not found")
  })

  if (node_result$status != 0) {
    cli::cli_abort(c(
      "Node.js is required but not found",
      "i" = "Install Node.js from https://nodejs.org/"
    ))
  }

  # Check npm
  npm_result <- tryCatch({
    processx::run(get_npm_command(), "--version", error_on_status = FALSE)
  }, error = function(e) {
    list(status = 1, stderr = "npm not found")
  })

  if (npm_result$status != 0) {
    cli::cli_abort(c(
      "npm is required but not found",
      "i" = "npm should be installed with Node.js"
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
