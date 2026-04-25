#' Check Shiny Application Readiness for Export
#'
#' Validates that a Shiny application can be built as an Electron app.
#' Checks app structure, configuration, runtime availability, dependencies,
#' and signing credentials. Reports issues without aborting.
#'
#' @param appdir Character string. Path to the app directory. Default ".".
#' @param app_type Character string or NULL. App type override.
#'   If NULL, reads from config or autodetects from files in `appdir`.
#' @param runtime_strategy Character string or NULL. Runtime strategy override.
#' @param platform Character vector or NULL. Target platforms override.
#' @param sign Logical or NULL. Signing override.
#' @param verbose Logical. Whether to print the report. Default TRUE.
#'
#' @return Invisible list with:
#'   \item{pass}{Logical. TRUE if no errors found.}
#'   \item{errors}{Character vector of fatal issues.}
#'   \item{warnings}{Character vector of non-fatal issues.}
#'   \item{info}{Character vector of informational notes.}
#'
#' @examples
#' \dontrun{
#' # Check current directory
#' app_check()
#'
#' # Check specific app
#' app_check("path/to/my/app")
#'
#' # Check with overrides
#' app_check("my-app", app_type = "r-shiny", runtime_strategy = "system")
#' }
#'
#' @export
app_check <- function(appdir = ".", app_type = NULL, runtime_strategy = NULL,
                      platform = NULL, sign = NULL, verbose = TRUE) {

  errors <- character(0)
  warnings <- character(0)
  info <- character(0)

  app_name <- basename(normalizePath(appdir, mustWork = FALSE))

  if (verbose) {
    cli::cli_h1("App Check: {app_name}")
  }

  # --- Check: Directory exists ---
  if (!fs::dir_exists(appdir)) {
    errors <- c(errors, paste0("App directory does not exist: ", appdir))
    if (verbose) cli::cli_alert_danger("App directory does not exist: {.path {appdir}}")
    result <- list(pass = FALSE, errors = errors, warnings = warnings, info = info)
    return(invisible(result))
  }

  # --- Read config ---
  config <- tryCatch({
    cfg <- read_config(appdir)
    if (verbose) {
      if (!is.null(find_config(appdir))) {
        cli::cli_alert_success("Config: {.file _shinyelectron.yml} valid")
      } else {
        cli::cli_alert_info("Config: no {.file _shinyelectron.yml} (using defaults)")
      }
    }
    cfg
  }, error = function(e) {
    warnings <- c(warnings, paste0("Config error: ", e$message))
    if (verbose) cli::cli_alert_warning("Config: {e$message}")
    list()
  })

  # Resolve parameters. Order: function arg > config > autodetect (type)
  # or default (strategy).
  normalized <- normalize_app_type_arg(app_type, runtime_strategy)
  app_type <- normalized$app_type
  runtime_strategy <- normalized$runtime_strategy

  if (is.null(app_type)) {
    cfg_type <- config$build$type
    if (!is.null(cfg_type) && nzchar(cfg_type)) {
      cfg_normalized <- normalize_app_type_arg(cfg_type, runtime_strategy)
      app_type <- cfg_normalized$app_type
      runtime_strategy <- runtime_strategy %||% cfg_normalized$runtime_strategy
    }
  }
  if (is.null(app_type)) {
    app_type <- tryCatch(detect_app_type(appdir), error = function(e) NULL)
    if (is.null(app_type)) {
      errors <- c(errors, "Could not determine app type (no app.R/app.py/server.R+ui.R found)")
      if (verbose) cli::cli_alert_danger("App type: could not autodetect")
      return(invisible(list(pass = FALSE, errors = errors, warnings = warnings, info = info)))
    }
  }
  runtime_strategy <- runtime_strategy %||% config$build$runtime_strategy %||% "shinylive"

  platform <- platform %||% config$build$platforms %||% detect_current_platform()
  sign <- sign %||% isTRUE(config$signing$sign)

  if (verbose) {
    cli::cli_alert_info("Type: {.val {app_type}}")
    cli::cli_alert_info("Runtime strategy: {.val {runtime_strategy}}")
    cli::cli_alert_info("Platform(s): {.val {platform}}")
  }

  # --- Check: App structure ---
  tryCatch({
    if (app_type == "r-shiny") {
      validate_shiny_app_structure(appdir)
      if (verbose) cli::cli_alert_success("App structure: {.file app.R} found")
    } else {
      validate_python_app_structure(appdir)
      if (verbose) cli::cli_alert_success("App structure: {.file app.py} found")
    }
  }, error = function(e) {
    errors <<- c(errors, conditionMessage(e))
    if (verbose) cli::cli_alert_danger("App structure: {e$message}")
  })

  # --- Check: Brand ---
  brand <- read_brand_yml(appdir)
  if (!is.null(brand)) {
    if (verbose) cli::cli_alert_success("Brand: {.file _brand.yml} valid")
  }

  # --- Check: Node.js ---
  tryCatch({
    node_info <- validate_node_npm()
    if (verbose) cli::cli_alert_success("Node.js: {node_info$node_version} + npm {node_info$npm_version}")
  }, error = function(e) {
    errors <<- c(errors, e$message)
    if (verbose) cli::cli_alert_danger("Node.js: {e$message}")
  })

  # --- Check: Runtime ---
  if (runtime_strategy == "system") {
    if (app_type == "r-shiny") {
      tryCatch({
        rscript_path <- validate_r_available()
        if (verbose) cli::cli_alert_success("R: available at {.path {rscript_path}}")
      }, error = function(e) {
        errors <<- c(errors, e$message)
        if (verbose) cli::cli_alert_danger("R: {e$message}")
      })
    }
    if (app_type == "py-shiny") {
      tryCatch({
        validate_python_available()
        if (verbose) cli::cli_alert_success("Python: available")

        # Check that Shiny for Python is installed
        if (app_type == "py-shiny") {
          tryCatch({
            ver <- validate_python_shiny_installed()
            if (verbose) cli::cli_alert_success("Python shiny: {ver}")
          }, error = function(e) {
            errors <<- c(errors, e$message)
            if (verbose) cli::cli_alert_danger("Python shiny: {e$message}")
          })
        }
      }, error = function(e) {
        errors <<- c(errors, e$message)
        if (verbose) cli::cli_alert_danger("Python: {e$message}")
      })
    }
  } else if (runtime_strategy == "container") {
    tryCatch({
      engine <- validate_container_available(config$container$engine)
      if (verbose) cli::cli_alert_success("Container engine: {.val {engine}}")
    }, error = function(e) {
      warnings <<- c(warnings, e$message)
      if (verbose) cli::cli_alert_warning("Container: {e$message}")
    })
  }

  # --- Check: shinylive tooling (only when strategy is shinylive) ---
  if (runtime_strategy == "shinylive") {
    if (app_type == "r-shiny") {
      if (requireNamespace("shinylive", quietly = TRUE)) {
        if (verbose) cli::cli_alert_success("shinylive R package: installed")
      } else {
        errors <- c(errors, "shinylive R package not installed")
        if (verbose) cli::cli_alert_danger("shinylive R package: not installed")
      }
    } else if (app_type == "py-shiny") {
      tryCatch({
        validate_python_available()
        validate_python_shinylive_installed()
        if (verbose) cli::cli_alert_success("Python shinylive: installed")
      }, error = function(e) {
        errors <<- c(errors, e$message)
        if (verbose) cli::cli_alert_danger("Python shinylive: {e$message}")
      })
    }
  }

  # --- Check: Dependencies ---
  tryCatch({
    dep_result <- resolve_app_dependencies(appdir, app_type, runtime_strategy, config)
    if (!is.null(dep_result) && length(dep_result$packages) > 0) {
      dep_msg <- paste(dep_result$packages, collapse = ", ")
      info <- c(info, paste0("Dependencies (", dep_result$language, "): ", dep_msg))
      if (verbose) cli::cli_alert_success("Dependencies: {dep_msg}")
    } else if (runtime_strategy == "shinylive") {
      # shinylive handles its own deps, so resolve_app_dependencies returns NULL.
      # Still scan for informational purposes.
      detected <- tryCatch({
        if (app_type == "r-shiny") detect_r_dependencies(appdir)
        else detect_py_dependencies(appdir)
      }, error = function(e) character(0))
      if (length(detected) > 0) {
        lang <- if (app_type == "r-shiny") "R" else "Python"
        dep_msg <- paste(detected, collapse = ", ")
        info <- c(info, paste0("Dependencies (", lang, "): ", dep_msg))
        if (verbose) cli::cli_alert_success("Dependencies: {dep_msg}")
      }
    } else {
      info <- c(info, "No dependencies detected")
      if (verbose) cli::cli_alert_info("Dependencies: none detected")
    }
  }, error = function(e) {
    warnings <<- c(warnings, paste0("Dependency check: ", e$message))
    if (verbose) cli::cli_alert_warning("Dependencies: {e$message}")
  })

  # --- Check: Signing ---
  if (sign) {
    if (verbose) cli::cli_alert_info("Code signing: {.val enabled}")
    # validate_signing_config emits warnings, doesn't error
    for (p in platform) {
      validate_signing_config(config, platform = p)
    }
  } else {
    info <- c(info, "Code signing: disabled")
    if (verbose) cli::cli_alert_info("Code signing: {.val disabled}")
  }

  # --- Check: Icon ---
  icon <- config$icons$mac %||% config$icons$win %||% config$icons$linux
  if (!is.null(icon)) {
    if (fs::file_exists(fs::path(appdir, icon))) {
      if (verbose) cli::cli_alert_success("Icon: {.file {icon}}")
    } else {
      warnings <- c(warnings, paste0("Icon file not found: ", icon))
      if (verbose) cli::cli_alert_warning("Icon: {.file {icon}} not found")
    }
  } else {
    info <- c(info, "Icon: not configured (default Electron icon)")
    if (verbose) cli::cli_alert_info("Icon: not configured (default Electron icon)")
  }

  # --- Result ---
  pass <- length(errors) == 0

  if (verbose) {
    cli::cli_h2("Result")
    if (pass) {
      cli::cli_alert_success("Ready to build! Run: {.code export(\"{appdir}\", \"output\")}")
    } else {
      cli::cli_alert_danger("{length(errors)} error{?s} found. Fix them before building.")
    }
    if (length(warnings) > 0) {
      cli::cli_alert_warning("{length(warnings)} warning{?s}")
    }
  }

  result <- list(
    pass = pass,
    errors = errors,
    warnings = warnings,
    info = info
  )

  invisible(result)
}
