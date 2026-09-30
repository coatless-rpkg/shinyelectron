#' Check Shiny Application Readiness for Export
#'
#' Validates that a Shiny application can be built as an Electron app.
#' Checks app structure, configuration, runtime availability, dependencies,
#' and signing credentials. Reports issues without aborting.
#'
#' Files named in `_shinyelectron.yml`, such as `icon` or `splash.image`, are
#' looked up relative to `appdir`, as [export()] does. A missing icon is an
#' error, because [export()] stops on it; other missing files are warnings.
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
#' \donttest{
#' # Check a bundled example app
#' app_check(example_app("r"))
#'
#' # Check with explicit overrides
#' app_check(example_app("r"), app_type = "r-shiny", runtime_strategy = "system")
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
  # read_config() reports YAML parse errors and questionable values as
  # warnings and carries on. A hard error (for example an invalid installer
  # setting) also stops export(), so it fails the check.
  read <- catch_conditions(read_config(appdir))
  for (msg in read$warnings) {
    warnings <- c(warnings, paste0("Config error: ", msg))
    if (verbose) cli::cli_alert_warning("Config: {msg}")
  }
  if (is.null(read$error)) {
    config <- read$value
    if (verbose) {
      if (is.null(find_config(appdir))) {
        cli::cli_alert_info("Config: no {.file _shinyelectron.yml} (using defaults)")
      } else if (length(read$warnings) == 0) {
        cli::cli_alert_success("Config: {.file _shinyelectron.yml} valid")
      }
    }
  } else {
    msg <- conditionMessage(read$error)
    errors <- c(errors, paste0("Config error: ", msg))
    if (verbose) cli::cli_alert_danger("Config: {msg}")
    config <- list()
  }

  # File paths in the config are relative to the app directory, as in export().
  config <- resolve_config_paths(config, appdir)

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
  err <- catch_error({
    if (app_type == "r-shiny") {
      validate_shiny_app_structure(appdir)
      entry <- if (fs::file_exists(fs::path(appdir, "app.R"))) {
        "app.R"
      } else {
        "server.R + ui.R"
      }
      if (verbose) cli::cli_alert_success("App structure: {.file {entry}} found")
    } else {
      validate_python_app_structure(appdir)
      if (verbose) cli::cli_alert_success("App structure: {.file app.py} found")
    }
  })
  if (!is.null(err)) {
    errors <- c(errors, conditionMessage(err))
    if (verbose) cli::cli_alert_danger("App structure: {err$message}")
  }

  # --- Check: Brand ---
  brand <- read_brand_yml(appdir)
  if (!is.null(brand)) {
    if (verbose) cli::cli_alert_success("Brand: {.file _brand.yml} valid")
  }

  # --- Check: Node.js ---
  err <- catch_error({
    node_info <- validate_node_npm()
    if (verbose) cli::cli_alert_success("Node.js: {node_info$node_version} + npm {node_info$npm_version}")
  })
  if (!is.null(err)) {
    errors <- c(errors, err$message)
    if (verbose) cli::cli_alert_danger("Node.js: {err$message}")
  }

  # --- Check: Runtime ---
  if (runtime_strategy == "system") {
    if (app_type == "r-shiny") {
      err <- catch_error({
        rscript_path <- validate_r_available()
        if (verbose) cli::cli_alert_success("R: available at {.path {rscript_path}}")
      })
      if (!is.null(err)) {
        errors <- c(errors, err$message)
        if (verbose) cli::cli_alert_danger("R: {err$message}")
      }
    }
    if (app_type == "py-shiny") {
      err <- catch_error({
        validate_python_available()
        if (verbose) cli::cli_alert_success("Python: available")
      })
      if (!is.null(err)) {
        errors <- c(errors, err$message)
        if (verbose) cli::cli_alert_danger("Python: {err$message}")
      } else {
        # Check that Shiny for Python is installed
        err <- catch_error({
          ver <- validate_python_shiny_installed()
          if (verbose) cli::cli_alert_success("Python shiny: {ver}")
        })
        if (!is.null(err)) {
          errors <- c(errors, err$message)
          if (verbose) cli::cli_alert_danger("Python shiny: {err$message}")
        }
      }
    }
  } else if (runtime_strategy == "container") {
    err <- catch_error({
      engine <- validate_container_available(config$container$engine)
      if (verbose) cli::cli_alert_success("Container engine: {.val {engine}}")
    })
    if (!is.null(err)) {
      warnings <- c(warnings, err$message)
      if (verbose) cli::cli_alert_warning("Container: {err$message}")
    }
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
      err <- catch_error({
        validate_python_available()
        validate_python_shinylive_installed()
        if (verbose) cli::cli_alert_success("Python shinylive: installed")
      })
      if (!is.null(err)) {
        errors <- c(errors, err$message)
        if (verbose) cli::cli_alert_danger("Python shinylive: {err$message}")
      }
    }
  }

  # --- Check: Dependencies ---
  err <- catch_error({
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
  })
  if (!is.null(err)) {
    warnings <- c(warnings, paste0("Dependency check: ", err$message))
    if (verbose) cli::cli_alert_warning("Dependencies: {err$message}")
  }

  # --- Check: Signing ---
  if (sign) {
    if (verbose) cli::cli_alert_info("Code signing: {.val enabled}")
    # validate_signing_config emits warnings, doesn't error
    for (p in platform) {
      validate_signing_config(config, platform = p, sign = sign)
    }
  } else {
    info <- c(info, "Code signing: disabled")
    if (verbose) cli::cli_alert_info("Code signing: {.val disabled}")
  }

  # --- Check: Icon ---
  # export() picks `icon`, or else the `icons` entry for the platform it
  # builds, and stops when that file does not exist, so a missing icon is an
  # error. Check the icon each target platform would use.
  icons <- unique(Filter(Negate(is.null),
                         lapply(platform, function(p) config_icon(config, p))))
  if (length(icons) == 0) {
    info <- c(info, "Icon: not configured (default Electron icon)")
    if (verbose) cli::cli_alert_info("Icon: not configured (default Electron icon)")
  }
  for (icon in icons) {
    shown <- paste(format(icon$path), collapse = " ")
    if (config_file_exists(icon$path)) {
      if (verbose) cli::cli_alert_success("Icon: {.file {shown}}")
    } else {
      errors <- c(errors, paste0(icon$field, " file not found: ", shown))
      if (verbose) cli::cli_alert_danger("Icon: {.field {icon$field}} file not found: {.path {shown}}")
    }
  }

  # --- Check: Other files named in the config ---
  # export() warns about these and builds without them. It also warns about a
  # missing Windows certificate when it signs a Windows build.
  for (entry in missing_config_files(config)) {
    shown <- paste(format(entry$path), collapse = " ")
    if (is.null(entry$id)) {
      warnings <- c(warnings, paste0(entry$field, " file not found: ", shown))
      if (verbose) cli::cli_alert_warning("{.field {entry$field}} file not found: {.path {shown}}")
    } else {
      warnings <- c(warnings, paste0(entry$field, " file of app ", entry$id,
                                     " not found: ", shown))
      if (verbose) cli::cli_alert_warning("{.field {entry$field}} file of app {.val {entry$id}} not found: {.path {shown}}")
    }
  }
  cert <- config_value(config, c("signing", "win", "certificate_file"))
  if (sign && "win" %in% platform && !is.null(cert) &&
      !config_file_exists(cert)) {
    shown <- paste(format(cert), collapse = " ")
    warnings <- c(warnings, paste0("signing.win.certificate_file file not found: ", shown))
    if (verbose) cli::cli_alert_warning("{.field signing.win.certificate_file} file not found: {.path {shown}}")
  }

  # --- Check: Installer license ---
  # export() resolves installer.license_file against the app directory and
  # stops when the file is missing.
  license_file <- config$installer$license_file
  if (!is.null(license_file)) {
    err <- catch_error(resolve_installer_license(config, appdir))
    if (is.null(err)) {
      if (verbose) cli::cli_alert_success("Installer license: {.file {license_file}}")
    } else {
      errors <- c(errors, conditionMessage(err))
      if (verbose) cli::cli_alert_danger("Installer license: {conditionMessage(err)}")
    }
  }

  # --- Check: App slug and installer text ---
  # export() stops on an app slug it cannot use, and on a $ in the text a
  # Windows installer shows when it builds for Windows; other builds warn.
  # Without an app_name argument, export() takes the slug from app.slug or
  # the directory name, and the display name from app.name or the directory
  # name.
  err <- catch_error({
    slug <- resolve_app_slug(config, NULL, normalizePath(appdir, mustWork = FALSE))
    check_app_slug(slug)
    if (verbose) cli::cli_alert_success("App slug: {.val {slug}}")
  })
  if (!is.null(err)) {
    errors <- c(errors, conditionMessage(err))
    if (verbose) cli::cli_alert_danger("App slug: {conditionMessage(err)}")
  }
  # Other warnings can come before the $ check, so keep them all and carry on.
  text <- catch_conditions(
    check_installer_text(config$app$name %||% app_name, config,
                         windows = "win" %in% platform)
  )
  for (msg in text$warnings) {
    warnings <- c(warnings, msg)
    if (verbose) cli::cli_alert_warning("Installer text: {msg}")
  }
  if (!is.null(text$error)) {
    msg <- conditionMessage(text$error)
    errors <- c(errors, msg)
    if (verbose) cli::cli_alert_danger("Installer text: {msg}")
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

#' Evaluate an expression and return its error
#'
#' Lets each check in [app_check()] record a failure in its own results.
#'
#' @param expr An expression, evaluated in the calling function's
#'   environment.
#' @return `NULL` when `expr` finishes without an error, otherwise the error
#'   condition.
#' @keywords internal
catch_error <- function(expr) {
  tryCatch({
    expr
    NULL
  }, error = identity)
}

#' Evaluate an expression, collecting its warnings and error
#'
#' Records every warning `expr` gives, in order, and lets it carry on, so
#' [app_check()] can report each one. An error ends the evaluation; the
#' warnings given before it are kept.
#'
#' @param expr An expression, evaluated in the calling function's
#'   environment.
#' @return A list with `value`, the value of `expr` or `NULL` after an error,
#'   `error`, the error condition or `NULL`, and `warnings`, the messages of
#'   the warnings given.
#' @keywords internal
catch_conditions <- function(expr) {
  # A calling handler cannot return values to the caller, so the warnings
  # go into a field of this local environment.
  collected <- new.env(parent = emptyenv())
  collected$warnings <- character(0)
  result <- tryCatch(
    list(
      value = withCallingHandlers(expr, warning = function(w) {
        collected$warnings <- c(collected$warnings, conditionMessage(w))
        invokeRestart("muffleWarning")
      }),
      error = NULL
    ),
    error = function(e) list(value = NULL, error = e)
  )
  c(result, list(warnings = collected$warnings))
}
