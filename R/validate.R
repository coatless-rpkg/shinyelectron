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
  valid_types <- SHINYELECTRON_DEFAULTS$valid_app_types
  if (!app_type %in% valid_types) {
    cli::cli_abort(c(
      "Invalid app_type: {.val {app_type}}",
      "i" = "Must be one of: {.val {valid_types}}",
      "i" = "See {.url https://r-pkg.thecoatlessprofessor.com/shinyelectron/articles/configuration.html}"
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

#' Validate Node.js and npm availability
#'
#' Checks for Node.js and npm, preferring locally installed versions
#' managed by shinyelectron over system installations.
#'
#' @return Invisibly returns a list with node and npm paths and versions.
#' @keywords internal
validate_node_npm <- function() {
  # Get commands (will prefer local if available)
  node_cmd <- get_node_command(prefer_local = TRUE)
  npm_cmd <- get_npm_command(prefer_local = TRUE)

  # Check if using local installation
  using_local <- nodejs_is_installed()

  # Check Node.js
  node_result <- tryCatch({
    processx::run(node_cmd, "--version", error_on_status = FALSE)
  }, error = function(e) {
    list(status = 1, stderr = "Node.js not found")
  })

  if (node_result$status != 0) {
    cli::cli_abort(c(
      "Node.js is required but not found",
      "i" = "Install locally with: {.code shinyelectron::install_nodejs()}",
      "i" = "Or install system-wide from https://nodejs.org/"
    ))
  }

  # Check npm
  npm_result <- tryCatch({
    processx::run(npm_cmd, "--version", error_on_status = FALSE)
  }, error = function(e) {
    list(status = 1, stderr = "npm not found")
  })

  if (npm_result$status != 0) {
    cli::cli_abort(c(
      "npm is required but not found",
      "i" = "npm should be installed with Node.js",
      "i" = "Try: {.code shinyelectron::install_nodejs()}"
    ))
  }

  invisible(list(
    node_path = node_cmd,
    node_version = trimws(gsub("^v", "", node_result$stdout)),
    npm_path = npm_cmd,
    npm_version = trimws(npm_result$stdout),
    using_local = using_local
  ))
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

#' Validate runtime strategy
#'
#' @param strategy Character string. The runtime strategy to validate.
#' @keywords internal
validate_runtime_strategy <- function(strategy) {
  valid <- SHINYELECTRON_DEFAULTS$valid_runtime_strategies
  if (!strategy %in% valid) {
    cli::cli_abort(c(
      "Invalid runtime strategy: {.val {strategy}}",
      "i" = "Valid strategies: {.val {valid}}"
    ))
  }
  invisible(TRUE)
}

#' Validate runtime strategy is compatible with app type
#'
#' @param strategy Character string. The runtime strategy.
#' @param app_type Character string. The app type.
#' @keywords internal
validate_runtime_strategy_for_app_type <- function(strategy, app_type) {
  shinylive_types <- c("r-shinylive", "py-shinylive")
  if (app_type %in% shinylive_types && strategy != "shinylive") {
    cli::cli_abort(c(
      "Runtime strategy {.val {strategy}} is not applicable to app type {.val {app_type}}",
      "i" = "Shinylive app types run entirely in the browser and do not need a runtime strategy"
    ))
  }
  invisible(TRUE)
}

#' Validate Python app structure
#'
#' @param appdir Character string. Path to the app directory.
#' @keywords internal
validate_python_app_structure <- function(appdir) {
  app_py <- fs::path(appdir, "app.py")
  if (!fs::file_exists(app_py)) {
    cli::cli_abort(c(
      "No {.file app.py} found in {.path {appdir}}",
      "i" = "Python Shiny apps must contain an {.file app.py} file"
    ))
  }
  invisible(TRUE)
}

#' Find the Python command
#'
#' Searches for python3 first, then python on the system PATH.
#'
#' @return Character string or NULL. The Python command name, or NULL if not found.
#' @keywords internal
find_python_command <- function() {
  # On Windows, prefer "python" (python3 is often a Windows Store alias that
  # doesn't work). On Unix, prefer "python3".
  candidates <- if (.Platform$OS.type == "windows") {
    c("python", "python3")
  } else {
    c("python3", "python")
  }

  for (cmd in candidates) {
    path <- Sys.which(cmd)
    if (nzchar(path)) {
      # Verify it actually runs (Windows Store aliases exist but fail)
      check <- tryCatch(
        processx::run(cmd, "--version", error_on_status = FALSE, timeout = 5),
        error = function(e) list(status = 1)
      )
      if (check$status == 0) return(cmd)
    }
  }
  NULL
}

#' Validate Python is available on the system
#'
#' @return Invisible TRUE if Python is found, otherwise aborts.
#' @keywords internal
validate_python_available <- function() {
  python_cmd <- find_python_command()

  if (is.null(python_cmd)) {
    cli::cli_abort(c(
      "Python is required for this operation but was not found",
      "i" = "Install Python from {.url https://www.python.org/downloads/}",
      "i" = "Ensure {.code python3} or {.code python} is on your PATH"
    ))
  }

  tryCatch({
    result <- processx::run(python_cmd, c("--version"),
                            error_on_status = FALSE, timeout = 10)
    if (result$status != 0) {
      cli::cli_abort(c(
        "Python is required but failed to run",
        "x" = "Command: {.code {python_cmd} --version}",
        "x" = "Error: {result$stderr}"
      ))
    }
  }, error = function(e) {
    cli::cli_abort(c(
      "Python is required but could not be executed",
      "x" = "Error: {e$message}"
    ))
  })

  invisible(TRUE)
}

#' Validate the Python shinylive package CLI is usable
#'
#' Mirrors the command preference used by `convert_py_to_shinylive()`: first
#' the `shinylive` console script on PATH, then `python -m shinylive` as a
#' fallback. Runs `--version` to confirm the CLI actually executes (an import
#' check is not enough — shinylive ships no `__main__.py`, so a package that
#' imports fine can still fail at export time).
#'
#' @return Invisible character string with the detected shinylive version.
#' @keywords internal
validate_python_shinylive_installed <- function() {
  shinylive_cmd <- Sys.which("shinylive")
  if (nzchar(shinylive_cmd)) {
    result <- processx::run(
      "shinylive", c("--version"),
      error_on_status = FALSE, timeout = 30
    )
    cmd_label <- "shinylive"
  } else {
    python_cmd <- find_python_command()
    if (is.null(python_cmd)) {
      cli::cli_abort("Python is required but was not found")
    }
    result <- processx::run(
      python_cmd, c("-m", "shinylive", "--version"),
      error_on_status = FALSE, timeout = 30
    )
    cmd_label <- paste(python_cmd, "-m shinylive")
  }

  if (result$status != 0) {
    stderr <- trimws(result$stderr %||% "")
    main_missing <- grepl("cannot be directly executed|No module named shinylive\\.__main__", stderr)
    hints <- c(
      "Install the CLI with: {.code pip install shinylive}"
    )
    if (main_missing) {
      hints <- c(
        "Your Python has shinylive as a module but the {.code shinylive} command is not on PATH.",
        "On Windows, pip installs scripts into {.path %APPDATA%\\\\Python\\\\Python3XX\\\\Scripts}; add that directory to PATH.",
        "Or (re)install with: {.code pip install --upgrade --force-reinstall shinylive}"
      )
    }
    cli::cli_abort(c(
      "The {.pkg shinylive} Python package CLI is required for py-shinylive conversion",
      stats::setNames(hints, rep("i", length(hints))),
      "x" = "Command: {.code {cmd_label} --version}",
      "x" = "Error: {stderr}"
    ))
  }

  invisible(trimws(paste0(result$stdout, result$stderr)))
}

#' Validate the Python shiny package is installed
#'
#' Used by the native `py-shiny` app type. Only checks importability — the
#' export pipeline spawns `python -m shiny run` at runtime on the user's
#' machine, not at build time.
#'
#' @return Invisible character string with the detected shiny version.
#' @keywords internal
validate_python_shiny_installed <- function() {
  python_cmd <- find_python_command()

  if (is.null(python_cmd)) {
    cli::cli_abort("Python is required but was not found")
  }

  result <- processx::run(
    python_cmd,
    c("-c", "import shiny; print(shiny.__version__)"),
    error_on_status = FALSE,
    timeout = 30
  )

  if (result$status != 0) {
    cli::cli_abort(c(
      "The {.pkg shiny} Python package is required for py-shiny apps",
      "i" = "Install with: {.code pip install shiny}",
      "x" = "Error: {trimws(result$stderr %||% '')}"
    ))
  }

  invisible(trimws(result$stdout))
}

#' Validate R is available on the system
#'
#' Checks that Rscript can be found and executed. This is used for the
#' "system" runtime strategy where the end user must have R installed.
#'
#' @return Invisible character string with the path to Rscript.
#' @keywords internal
validate_r_available <- function() {
  rscript <- Sys.which("Rscript")

  if (!nzchar(rscript)) {
    cli::cli_abort(c(
      "Rscript is required but was not found on the system PATH",
      "i" = "Install R from {.url https://cran.r-project.org/}",
      "i" = "Ensure {.code Rscript} is on your PATH"
    ))
  }

  tryCatch({
    result <- processx::run(rscript, c("--version"),
                            error_on_status = FALSE, timeout = 10)
    if (result$status != 0) {
      cli::cli_abort(c(
        "Rscript was found but failed to run",
        "x" = "Path: {.path {rscript}}",
        "x" = "Error: {result$stderr}"
      ))
    }
  }, error = function(e) {
    cli::cli_abort(c(
      "Rscript was found but could not be executed",
      "x" = "Path: {.path {rscript}}",
      "x" = "Error: {e$message}"
    ))
  })

  invisible(rscript)
}

#' Validate a container engine is available
#'
#' Checks that Docker or Podman is installed and can be executed.
#'
#' @param preference Character string or NULL. Preferred engine.
#' @return Invisible character string with the engine name.
#' @keywords internal
validate_container_available <- function(preference = NULL) {
  engine <- detect_container_engine(preference)

  if (is.null(engine)) {
    cli::cli_abort(c(
      "Neither Docker nor Podman was found on the system",
      "i" = "Install Docker: {.url https://docs.docker.com/get-docker/}",
      "i" = "Install Podman: {.url https://podman.io/getting-started/installation}"
    ))
  }

  tryCatch({
    result <- processx::run(engine, c("info"),
                            error_on_status = FALSE, timeout = 15)
    if (result$status != 0) {
      cli::cli_abort(c(
        "{.strong {engine}} is installed but not running",
        "i" = "Start the {engine} daemon and try again",
        "x" = "Error: {result$stderr}"
      ))
    }
  }, error = function(e) {
    cli::cli_abort(c(
      "{.strong {engine}} was found but could not be executed",
      "x" = "Error: {e$message}"
    ))
  })

  invisible(engine)
}

#' Infer the default runtime strategy for an app type
#'
#' @param strategy Character string or NULL. Explicit strategy, or NULL to infer.
#' @param app_type Character string. The app type.
#' @return Character string. The resolved runtime strategy.
#' @keywords internal
infer_runtime_strategy <- function(strategy, app_type) {
  if (!is.null(strategy)) {
    return(strategy)
  }
  shinylive_types <- c("r-shinylive", "py-shinylive")
  if (app_type %in% shinylive_types) {
    "shinylive"
  } else {
    "auto-download"
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

#' Check if config is multi-app mode
#'
#' @param config List. Configuration.
#' @return Logical.
#' @keywords internal
is_multi_app <- function(config) {
  !is.null(config$apps) && is.list(config$apps) && length(config$apps) >= 2
}

#' Resolve the app type for a multi-app entry
#'
#' @param app List. Single app entry from config$apps.
#' @param config List. Full configuration.
#' @return Character string. The resolved app type.
#' @keywords internal
resolve_app_type <- function(app, config) {
  app$type %||% config$build$type %||% "r-shinylive"
}

#' Validate multi-app configuration
#'
#' @param config List. Configuration with apps array.
#' @param basedir Character. Base directory for resolving relative paths.
#' @keywords internal
validate_multi_app_config <- function(config, basedir) {
  apps <- config$apps

  # Check for required fields
  for (i in seq_along(apps)) {
    app <- apps[[i]]
    if (is.null(app$id) || !nzchar(app$id)) {
      cli::cli_abort("App entry {i} is missing required {.field id}")
    }
    if (is.null(app$name) || !nzchar(app$name)) {
      cli::cli_abort("App entry {i} ({app$id}) is missing required {.field name}")
    }
    if (is.null(app$path) || !nzchar(app$path)) {
      cli::cli_abort("App entry {i} ({app$id}) is missing required {.field path}")
    }
  }

  # Check for duplicate ids
  ids <- vapply(apps, function(a) a$id, character(1))
  dupes <- ids[duplicated(ids)]
  if (length(dupes) > 0) {
    cli::cli_abort("Duplicate app id{?s}: {.val {dupes}}")
  }

  # Validate each app directory and structure
  for (app in apps) {
    app_path <- fs::path(basedir, app$path)
    if (!fs::dir_exists(app_path)) {
      cli::cli_abort("App {.val {app$id}} directory does not exist: {.path {app_path}}")
    }

    app_type <- resolve_app_type(app, config)
    if (grepl("^r-", app_type)) {
      validate_shiny_app_structure(app_path)
    } else if (grepl("^py-", app_type)) {
      validate_python_app_structure(app_path)
    }
  }

  invisible(TRUE)
}
