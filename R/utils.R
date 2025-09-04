#' Utility functions for shinyelectron package
#'
#' @name utils
#' @keywords internal
NULL

#' Detect current platform
#'
#' @return Character string representing current platform ("win", "mac", or "linux")
#' @keywords internal
detect_current_platform <- function() {
  sysname <- Sys.info()[["sysname"]]
  switch(sysname,
         "Windows" = "win",
         "Darwin" = "mac",
         "Linux" = "linux",
         cli::cli_abort("Unsupported platform: {sysname}")
  )
}

#' Detect current architecture
#'
#' @return Character string representing current architecture ("x64" or "arm64")
#' @keywords internal
detect_current_arch <- function() {
  machine <- Sys.info()[["machine"]]
  if (grepl("arm|aarch", machine, ignore.case = TRUE)) {
    "arm64"
  } else {
    "x64"
  }
}

#' Get npm command
#'
#' @return Character string for npm command (handles different platforms)
#' @keywords internal
get_npm_command <- function() {
  if (Sys.info()[["sysname"]] == "Windows") {
    "npm.cmd"
  } else {
    "npm"
  }
}

#' Set development environment variables
#'
#' @param port Integer port number
#' @param open_devtools Logical whether to open dev tools
#' @return Named list of old environment variables
#' @keywords internal
set_dev_environment <- function(port, open_devtools) {
  old_env <- list(
    ELECTRON_DEV_PORT = Sys.getenv("ELECTRON_DEV_PORT", NA),
    ELECTRON_DEV_TOOLS = Sys.getenv("ELECTRON_DEV_TOOLS", NA)
  )

  Sys.setenv(
    ELECTRON_DEV_PORT = as.character(port),
    ELECTRON_DEV_TOOLS = if (open_devtools) "true" else "false"
  )

  old_env
}

#' Restore environment variables
#'
#' @param old_env Named list of environment variables to restore
#' @keywords internal
restore_environment <- function(old_env) {
  for (var_name in names(old_env)) {
    old_value <- old_env[[var_name]]
    if (is.na(old_value)) {
      Sys.unsetenv(var_name)
    } else {
      do.call(Sys.setenv, stats::setNames(list(old_value), var_name))
    }
  }
}

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

  if (fs::dir_exists(dest_app_dir)) {
    unlink(dest_app_dir, recursive = TRUE)
  }

  fs::dir_copy(app_dir, dest_app_dir)

  if (verbose) {
    cli::cli_alert_success("Copied application files")
  }
}

#' Process and copy Electron templates
#'
#' @param output_dir Character destination directory
#' @param app_name Character application name
#' @param app_type Character application type
#' @param icon Character path to icon file or NULL
#' @param verbose Logical whether to show progress
#' @keywords internal
process_templates <- function(output_dir, app_name, app_type, icon = NULL, verbose = TRUE) {
  if (verbose) {
    cli::cli_alert_info("Processing Electron templates...")
  }

  # Get template directory
  template_dir <- system.file("electron", app_type, package = "shinyelectron")

  if (!fs::dir_exists(template_dir)) {
    cli::cli_abort("Template directory not found for app type: {app_type}")
  }

  # Template variables
  template_vars <- list(
    app_name = app_name,
    app_type = app_type,
    has_icon = !is.null(icon)
  )

  # Process each template file
  template_files <- list.files(template_dir, recursive = TRUE, full.names = TRUE)

  for (template_file in template_files) {
    # Read template content
    template_content <- readLines(template_file, warn = FALSE)
    template_content <- paste(template_content, collapse = "\n")

    # Process with whisker
    processed_content <- whisker::whisker.render(template_content, template_vars)

    # Determine output path
    rel_path <- fs::path_rel(template_file, template_dir)
    output_path <- fs::path(output_dir, rel_path)

    # Create output directory if needed
    output_parent <- dirname(output_path)
    if (!fs::dir_exists(output_parent)) {
      fs::dir_create(output_parent, recurse = TRUE)
    }

    # Write processed content
    writeLines(processed_content, output_path)
  }

  # Copy icon if provided
  if (!is.null(icon)) {
    icon_ext <- tools::file_ext(icon)
    icon_dest <- fs::path(output_dir, "assets", paste0("icon.", icon_ext))
    fs::file_copy(icon, icon_dest, overwrite = TRUE)
  }

  if (verbose) {
    cli::cli_alert_success("Processed Electron templates")
  }
}

#' Install npm dependencies
#'
#' @param output_dir Character Electron project directory
#' @param verbose Logical whether to show progress
#' @keywords internal
install_npm_dependencies <- function(output_dir, verbose = TRUE) {
  if (verbose) {
    cli::cli_alert_info("Installing npm dependencies...")
  }

  # Change to output directory
  old_wd <- getwd()
  setwd(output_dir)
  on.exit(setwd(old_wd))

  # Run npm install
  result <- processx::run(
    command = get_npm_command(),
    args = c("install"),
    wd = ".",
    echo = verbose,
    spinner = verbose,
    error_on_status = FALSE
  )

  if (result$status != 0) {
    cli::cli_abort(c(
      "Failed to install npm dependencies",
      "x" = "Exit code: {result$status}",
      "i" = "stderr: {result$stderr}"
    ))
  }

  if (verbose) {
    cli::cli_alert_success("Installed npm dependencies")
  }
}


#' Build for target platforms
#'
#' @param output_dir Character Electron project directory
#' @param platform Character vector of target platforms
#' @param arch Character vector of target architectures
#' @param verbose Logical whether to show progress
#' @keywords internal
build_for_platforms <- function(output_dir, platform, arch, verbose = TRUE) {
  if (verbose) {
    cli::cli_alert_info("Building for platforms: {paste(platform, collapse = ', ')}")
  }

  # Change to output directory
  old_wd <- getwd()
  setwd(output_dir)
  on.exit(setwd(old_wd))

  # Check package.json exists and has necessary scripts
  package_json_path <- fs::path("package.json")
  if (!fs::file_exists(package_json_path)) {
    cli::cli_abort("No package.json found in: {.path {output_dir}}")
  }

  package_json <- jsonlite::fromJSON(package_json_path, simplifyVector = FALSE)
  available_scripts <- names(package_json$scripts %||% list())

  if (verbose) {
    cli::cli_alert_info("Available npm scripts: {paste(available_scripts, collapse = ', ')}")
  }

  # Build for each platform/arch combination
  for (p in platform) {
    for (a in arch) {
      target <- paste0(p, "-", a)

      if (verbose) {
        cli::cli_alert_info("Building for {target}...")
      }

      # Try specific platform-arch script first
      build_script <- paste0("build-", p, "-", a)

      if (build_script %in% available_scripts) {
        result <- processx::run(
          command = get_npm_command(),
          args = c("run", build_script),
          wd = ".",
          echo = verbose,
          spinner = verbose,
          cleanup_tree = TRUE,
          windows_hide_window = TRUE,
          error_on_status = FALSE
        )

        if (result$status == 0) {
          if (verbose) cli::cli_alert_success("Built for {target}")
          next
        } else {
          if (verbose) cli::cli_alert_warning("Specific script {build_script} failed: {result$stderr}")
        }
      } else {
        if (verbose) cli::cli_alert_info("Script {build_script} not found, trying platform-only build")
      }

      # Fallback to platform-only build
      platform_script <- paste0("build-", p)

      if (platform_script %in% available_scripts) {
        if (verbose) {
          cli::cli_alert_info("Trying fallback build for {p}...")
        }

        fallback_result <- processx::run(
          command = get_npm_command(),
          args = c("run", platform_script),
          wd = ".",
          echo = verbose,
          spinner = verbose,
          error_on_status = FALSE
        )

        if (fallback_result$status == 0) {
          cli::cli_alert_success("Built for {p} (fallback - may include multiple architectures)")
        } else {
          cli::cli_alert_warning("Fallback build also failed for {p}: {fallback_result$stderr}")
        }
      } else {
        cli::cli_alert_warning("No build script found for platform {p}")
      }
    }
  }
}
