#' Export Shiny Application as Electron Desktop Application
#'
#' Main entry point function that wraps the conversion, building, and optionally
#' running of a Shiny application as an Electron desktop application.
#'
#' @param appdir Character string. Path to the directory containing the Shiny application.
#' @param destdir Character string. Path to the destination directory where the Electron app will be created.
#' @param app_name Character string. Name of the application. If NULL, uses the base name of appdir.
#' @param app_type Character string. Type of application: "r-shinylive" (default), "r-shiny", "py-shinylive", or "py-shiny".
#' @param runtime_strategy Character string or NULL. Runtime strategy for native app types:
#'   "bundled", "system", "auto-download", or "container". If NULL, defaults to
#'   "auto-download" for native types. Ignored for shinylive types.
#' @param sign Logical. Whether to enable code signing for the built application.
#'   When TRUE, electron-builder will attempt to sign the app using credentials
#'   from environment variables or the config file. Default is FALSE.
#' @param platform Character vector. Target platforms: "win", "mac", "linux". If NULL, builds for current platform.
#' @param arch Character vector. Target architectures: "x64", "arm64". If NULL, uses current architecture.
#' @param icon Character string. Path to application icon file. Platform-specific format required.
#' @param overwrite Logical. Whether to overwrite existing output directory. Default is FALSE.
#' @param build Logical. Whether to build distributable packages. Default is TRUE.
#' @param run_after Logical. Whether to run the application in development mode after export. Default is FALSE.
#' @param open_after Logical. Whether to open the generated project directory after export. Default is FALSE.
#' @param verbose Logical. Whether to display detailed progress information. Default is TRUE.
#'
#' @return List containing paths to the converted app and built Electron app (if built).
#'
#' @section Details:
#' This is the main function of the package that orchestrates the entire process:
#' \itemize{
#'   \item Validates the input Shiny application
#'   \item Converts the Shiny app to the specified format (shinylive by default)
#'   \item Sets up the Electron project structure
#'   \item Optionally builds distributable packages
#'   \item Optionally runs the application for testing
#' }
#'
#' @section Supported Application Types:
#' \itemize{
#'   \item \code{r-shinylive}: R Shiny app converted to run entirely in browser (recommended)
#'   \item \code{r-shiny}: R Shiny app with embedded R runtime
#'   \item \code{py-shinylive}: Python Shiny app converted to run entirely in browser
#'   \item \code{py-shiny}: Python Shiny app with embedded Python runtime
#' }
#'
#' @examples
#' \dontrun{
#' # Basic export to shinylive Electron app
#' export(
#'   appdir = "path/to/shiny/app",
#'   destdir = "path/to/electron/output"
#' )
#'
#' # Export with custom settings
#' export(
#'   appdir = "path/to/shiny/app",
#'   destdir = "path/to/output",
#'   app_name = "My Amazing App",
#'   app_type = "r-shinylive",
#'   platform = c("win", "mac"),
#'   icon = "path/to/icon.ico",
#'   overwrite = TRUE,
#'   run_after = TRUE
#' )
#'
#' # Export regular Shiny app (with R runtime)
#' export(
#'   appdir = "path/to/shiny/app",
#'   destdir = "path/to/output",
#'   app_type = "r-shiny"
#' )
#'
#' }
#'
#' @export
export <- function(appdir, destdir, app_name = NULL, app_type = "r-shinylive",
                   runtime_strategy = NULL, sign = FALSE,
                   platform = NULL, arch = NULL, icon = NULL,
                   overwrite = FALSE, build = TRUE, run_after = FALSE,
                   open_after = FALSE, verbose = TRUE) {

  # Expand ~ in paths before passing to external tools (Python, npm, etc.)
  appdir <- path.expand(appdir)
  destdir <- path.expand(destdir)

  # Validate inputs
  validate_directory_exists(appdir, "Application directory")
  validate_app_type(app_type)

  if (is.null(app_name)) {
    app_name <- basename(appdir)
  }
  validate_app_name(app_name)

  # Read config file (or get defaults) -- must happen before structure

  # validation so multi-app mode can be detected early
  config <- read_config(appdir)

  # Detect multi-app mode (skip single-app structure validation)
  if (is_multi_app(config)) {
    return(export_multi_app(appdir, destdir, config,
                            runtime_strategy = runtime_strategy,
                            sign = sign, platform = platform, arch = arch,
                            icon = icon, overwrite = overwrite, build = build,
                            run_after = run_after, open_after = open_after,
                            verbose = verbose))
  }

  # Validate app structure based on type (single-app only)
  if (app_type %in% c("r-shinylive", "r-shiny")) {
    validate_shiny_app_structure(appdir)
  } else if (app_type %in% c("py-shinylive", "py-shiny")) {
    validate_python_app_structure(appdir)
  }

  # Validate icon file if provided
  if (!is.null(icon)) {
    validate_icon(icon, platform)
  }

  # Resolve runtime strategy: function param > config file > inferred default
  runtime_strategy <- runtime_strategy %||% config$build$runtime_strategy
  runtime_strategy <- infer_runtime_strategy(runtime_strategy, app_type)
  if (runtime_strategy != "shinylive") {
    validate_runtime_strategy(runtime_strategy)
  }
  validate_runtime_strategy_for_app_type(runtime_strategy, app_type)

  # Resolve signing: function param overrides config
  sign <- sign || isTRUE(config$signing$sign)

  # Validate signing credentials (warns, doesn't error)
  if (sign && build) {
    sign_platforms <- platform %||% detect_current_platform()
    for (p in sign_platforms) {
      validate_signing_config(config, platform = p)
    }
  }

  # Validate runtime requirements
  if (runtime_strategy == "system") {
    if (app_type %in% c("r-shiny")) {
      validate_r_available()
    } else if (app_type %in% c("py-shiny")) {
      validate_python_available()
    }
  }

  if (runtime_strategy == "container") {
    engine <- tryCatch(
      validate_container_available(config$container$engine),
      error = function(e) {
        cli::cli_warn(c(
          "Container engine not available on build machine (end user will need it)",
          "i" = e$message
        ))
        config$container$engine %||% "docker"
      }
    )
    if (verbose) {
      cli::cli_alert_info("Container engine: {.val {engine}}")
    }
  }

  if (verbose) {
    cli::cli_h1("Exporting Shiny application to Electron")
    cli::cli_alert_info("Application: {.val {app_name}}")
    cli::cli_alert_info("Type: {.val {app_type}}")
    if (app_type %in% c("r-shiny", "py-shiny")) {
      cli::cli_alert_info("Runtime: {.val {runtime_strategy}}")
    }
    cli::cli_alert_info("Source: {.path {appdir}}")
    cli::cli_alert_info("Destination: {.path {destdir}}")
    if (sign) {
      cli::cli_alert_info("Code signing: {.val enabled}")
    } else {
      cli::cli_alert_info("Code signing: {.val disabled} (unsigned build)")
    }
  }

  # Create destination directory
  if (fs::dir_exists(destdir)) {
    if (!overwrite) {
      cli::cli_abort(c(
        "Destination directory already exists: {.path {destdir}}",
        "i" = "Use {.code overwrite = TRUE} to overwrite existing directory"
      ))
    } else {
      if (verbose) cli::cli_alert_warning("Overwriting existing directory: {.path {destdir}}")
      # Safety check: refuse to overwrite critical system directories
      abs_dest <- normalizePath(destdir, mustWork = FALSE)
      protected <- c(
        normalizePath("~", mustWork = FALSE),
        normalizePath("/", mustWork = FALSE),
        normalizePath(R.home(), mustWork = FALSE)
      )
      if (abs_dest %in% protected || nchar(abs_dest) <= 3) {
        cli::cli_abort("Refusing to overwrite protected directory: {.path {destdir}}")
      }
      unlink(destdir, recursive = TRUE)
    }
  }

  fs::dir_create(destdir, recurse = TRUE)

  result <- list()

  tryCatch({
    # Step 1: Convert application based on type
    converted_app_dir <- NULL

    if (app_type %in% c("r-shinylive", "py-shinylive")) {
      if (verbose) cli::cli_alert_info("Converting to shinylive format...")

      shinylive_dir <- fs::path(destdir, "shinylive-app")

      if (app_type == "r-shinylive") {
        converted_app_dir <- convert_shiny_to_shinylive(
          appdir = appdir,
          output_dir = shinylive_dir,
          overwrite = TRUE,
          verbose = verbose
        )
      } else {
        converted_app_dir <- convert_py_to_shinylive(
          appdir = appdir,
          output_dir = shinylive_dir,
          overwrite = TRUE,
          verbose = verbose
        )
      }

      result$converted_app <- converted_app_dir

    } else {
      # For regular Shiny apps, just copy the source
      if (verbose) cli::cli_alert_info("Preparing application files...")

      app_copy_dir <- fs::path(destdir, "shiny-app")
      copy_dir_contents(appdir, app_copy_dir)
      converted_app_dir <- app_copy_dir
      result$converted_app <- converted_app_dir

      # Resolve dependencies for native app types
      dep_info <- resolve_app_dependencies(appdir, app_type, config)
      if (!is.null(dep_info) && length(dep_info$packages) > 0) {
        if (verbose) {
          cli::cli_alert_info("Detected {length(dep_info$packages)} {dep_info$language} package dependencies")
          cli::cli_alert_info("Packages: {paste(dep_info$packages, collapse = ', ')}")
        }

        # Write dependency manifest for runtime installation
        manifest <- generate_dependency_manifest(
          packages = dep_info$packages,
          language = dep_info$language,
          repos = dep_info$repos,
          index_urls = dep_info$index_urls
        )
        writeLines(manifest, fs::path(converted_app_dir, "dependencies.json"))
        result$dependencies <- dep_info
      }

      # Write runtime manifest for auto-download strategy
      if (runtime_strategy == "auto-download") {
        if (grepl("^r-", app_type)) {
          r_version <- config$r$version %||% r_latest_version()
          runtime_manifest <- generate_runtime_manifest(
            version = r_version,
            platform = platform[1] %||% detect_current_platform(),
            arch = arch[1] %||% detect_current_arch()
          )
          writeLines(runtime_manifest, fs::path(converted_app_dir, "runtime-manifest.json"))
          if (verbose) cli::cli_alert_info("Runtime manifest written for R {r_version}")
        } else if (grepl("^py-", app_type)) {
          py_version <- config$python$version %||% "3.12.10"
          runtime_manifest <- generate_python_runtime_manifest(
            version = py_version,
            platform = platform[1] %||% detect_current_platform(),
            arch = arch[1] %||% detect_current_arch()
          )
          writeLines(runtime_manifest, fs::path(converted_app_dir, "runtime-manifest.json"))
          if (verbose) cli::cli_alert_info("Runtime manifest written for Python {py_version}")
        }
      }
    }

    # Step 2: Build Electron application if requested
    if (build) {
      if (verbose) cli::cli_alert_info("Building Electron application...")

      electron_dir <- fs::path(destdir, "electron-app")

      built_app_dir <- build_electron_app(
        app_dir = converted_app_dir,
        output_dir = electron_dir,
        app_name = app_name,
        app_type = app_type,
        runtime_strategy = runtime_strategy,
        sign = sign,
        platform = platform,
        arch = arch,
        icon = icon,
        config = config,
        overwrite = TRUE,
        verbose = verbose
      )

      result$electron_app <- built_app_dir
    }

    # Step 3: Run application in development mode if requested
    if (run_after && build) {
      if (verbose) cli::cli_alert_info("Starting application in development mode...")

      run_electron_app(
        app_dir = result$electron_app,
        verbose = verbose
      )
    }

    # Step 4: Open output directory if requested
    if (open_after) {
      if (verbose) cli::cli_alert_info("Opening output directory...")
      utils::browseURL(destdir)
    }

    if (verbose) {
      cli::cli_alert_success("Successfully exported Shiny application to Electron!")
      cli::cli_alert_info("Output directory: {.path {destdir}}")

      if (build) {
        cli::cli_alert_info("Electron app: {.path {result$electron_app}}")
        if (fs::dir_exists(fs::path(result$electron_app, "dist"))) {
          cli::cli_alert_info("Distributables: {.path {fs::path(result$electron_app, 'dist')}}")
        }
      }
    }

    return(result)

  }, error = function(e) {
    cli::cli_abort(c(
      "Failed to export Shiny application",
      "x" = "Error: {e$message}"
    ), parent = e)
  })
}

#' Export multi-app Shiny suite as Electron application
#' @keywords internal
export_multi_app <- function(appdir, destdir, config,
                              runtime_strategy = NULL, sign = FALSE,
                              platform = NULL, arch = NULL, icon = NULL,
                              overwrite = FALSE, build = TRUE,
                              run_after = FALSE, open_after = FALSE,
                              verbose = TRUE) {

  app_name <- config$app$name %||% basename(appdir)
  app_type <- config$build$type %||% "r-shiny"
  runtime_strategy <- runtime_strategy %||% config$build$runtime_strategy
  runtime_strategy <- infer_runtime_strategy(runtime_strategy, app_type)

  if (verbose) {
    cli::cli_h1("Exporting multi-app Shiny suite to Electron")
    cli::cli_alert_info("Suite: {.val {app_name}}")
    cli::cli_alert_info("Apps: {length(config$apps)}")
    cli::cli_alert_info("Default type: {.val {app_type}}")
  }

  # Validate multi-app config
  validate_multi_app_config(config, appdir)

  # Create destination
  if (fs::dir_exists(destdir)) {
    if (!overwrite) {
      cli::cli_abort("Destination directory already exists: {.path {destdir}}")
    }
    # Safety check: refuse to overwrite critical system directories
    abs_dest <- normalizePath(destdir, mustWork = FALSE)
    protected <- c(
      normalizePath("~", mustWork = FALSE),
      normalizePath("/", mustWork = FALSE),
      normalizePath(R.home(), mustWork = FALSE)
    )
    if (abs_dest %in% protected || nchar(abs_dest) <= 3) {
      cli::cli_abort("Refusing to overwrite protected directory: {.path {destdir}}")
    }
    unlink(destdir, recursive = TRUE)
  }
  fs::dir_create(destdir, recurse = TRUE)

  result <- list()

  tryCatch({
    # Step 1: Process each app
    apps_dir <- fs::path(destdir, "apps")
    fs::dir_create(apps_dir)

    # For Python multi-app suites, read dependencies from the suite root
    # (requirements.txt / pyproject.toml). All apps share one runtime/venv,
    # so a single global dep list is the right abstraction.
    suite_py_deps <- NULL
    if (grepl("^py-", app_type)) {
      suite_py_deps <- detect_py_dependencies(appdir)
      if (length(suite_py_deps) > 0) {
        config_deps <- config$dependencies %||% SHINYELECTRON_DEFAULTS$dependencies
        merged <- merge_py_dependencies(suite_py_deps, config_deps)
        suite_py_deps <- list(
          language = "python",
          packages = merged$packages,
          index_urls = merged$index_urls
        )
        if (verbose) {
          cli::cli_alert_info("Detected {length(suite_py_deps$packages)} Python package dependencies (suite-level)")
          cli::cli_alert_info("Packages: {paste(suite_py_deps$packages, collapse = ', ')}")
        }
      } else {
        suite_py_deps <- NULL
      }
    }

    apps_manifest <- list()

    for (app_entry in config$apps) {
      app_id <- app_entry$id
      app_src <- fs::path(appdir, app_entry$path)
      app_dest <- fs::path(apps_dir, app_id)
      this_type <- resolve_app_type(app_entry, config)

      if (verbose) cli::cli_alert_info("Processing app: {.val {app_entry$name}} ({this_type})")

      # Convert or copy based on type
      if (this_type %in% c("r-shinylive", "py-shinylive")) {
        if (this_type == "r-shinylive") {
          convert_shiny_to_shinylive(appdir = app_src, output_dir = app_dest,
                                     overwrite = TRUE, verbose = verbose)
        } else {
          convert_py_to_shinylive(appdir = app_src, output_dir = app_dest,
                                  overwrite = TRUE, verbose = verbose)
        }
      } else {
        copy_dir_contents(app_src, app_dest)

        # Write dependencies: Python uses the suite-level deps (one global
        # requirements.txt), R detects per-app from code.
        dep_info <- if (grepl("^py-", this_type) && !is.null(suite_py_deps)) {
          suite_py_deps
        } else {
          resolve_app_dependencies(app_src, this_type, config)
        }

        if (!is.null(dep_info) && length(dep_info$packages) > 0) {
          manifest <- generate_dependency_manifest(
            packages = dep_info$packages,
            language = dep_info$language,
            repos = dep_info$repos,
            index_urls = dep_info$index_urls
          )
          writeLines(manifest, fs::path(app_dest, "dependencies.json"))
        }
      }

      # Build manifest entry (use NA for missing icon so jsonlite writes null, not {})
      app_icon <- if (is.null(app_entry$icon) || !nzchar(app_entry$icon %||% "")) NA else app_entry$icon
      apps_manifest <- c(apps_manifest, list(list(
        id = app_id,
        name = app_entry$name,
        description = app_entry$description %||% "",
        path = paste0("src/apps/", app_id),
        type = this_type,
        icon = app_icon
      )))
    }

    result$apps <- apps_manifest

    # Step 2: Build Electron application
    if (build) {
      if (verbose) cli::cli_alert_info("Building Electron application...")

      electron_dir <- fs::path(destdir, "electron-app")

      # Write apps manifest for the Electron app
      fs::dir_create(electron_dir, recurse = TRUE)

      built_app_dir <- build_multi_app(
        apps_dir = apps_dir,
        output_dir = electron_dir,
        app_name = app_name,
        apps_manifest = apps_manifest,
        default_type = app_type,
        runtime_strategy = runtime_strategy,
        sign = sign,
        platform = platform,
        arch = arch,
        icon = icon,
        config = config,
        overwrite = TRUE,
        verbose = verbose
      )

      result$electron_app <- built_app_dir
    }

    # Step 3: Run application in development mode if requested
    if (run_after && build) {
      if (verbose) cli::cli_alert_info("Starting application in development mode...")

      run_electron_app(
        app_dir = result$electron_app,
        verbose = verbose
      )
    }

    if (verbose) {
      cli::cli_alert_success("Successfully exported multi-app suite!")
      cli::cli_alert_info("Output: {.path {destdir}}")
    }

    return(result)

  }, error = function(e) {
    cli::cli_abort(c(
      "Failed to export multi-app suite",
      "x" = "Error: {e$message}"
    ), parent = e)
  })
}

#' Build multi-app Electron application
#' @keywords internal
build_multi_app <- function(apps_dir, output_dir, app_name,
                             apps_manifest, default_type,
                             runtime_strategy, sign, platform, arch,
                             icon, config, overwrite, verbose) {

  if (is.null(platform)) platform <- detect_current_platform()
  if (is.null(arch)) arch <- detect_current_arch()

  validate_node_npm()

  fs::dir_create(output_dir, recurse = TRUE)

  # Setup project structure
  setup_electron_project(output_dir, app_name, default_type, verbose = verbose)

  # Copy all apps to src/apps/
  src_apps_dir <- fs::path(output_dir, "src", "apps")
  fs::dir_create(src_apps_dir, recurse = TRUE)

  for (app_id_dir in list.dirs(apps_dir, recursive = FALSE, full.names = TRUE)) {
    app_id <- basename(app_id_dir)
    copy_dir_contents(app_id_dir, fs::path(src_apps_dir, app_id))
  }

  # Write apps-manifest.json
  manifest_data <- list(
    apps = apps_manifest,
    default_type = default_type,
    runtime_strategy = runtime_strategy
  )
  writeLines(
    jsonlite::toJSON(manifest_data, pretty = TRUE, auto_unbox = TRUE),
    fs::path(output_dir, "apps-manifest.json")
  )

  # Process templates (pass multi-app flag)
  process_templates(output_dir, app_name, default_type,
                    runtime_strategy = runtime_strategy,
                    icon = icon, config = config, sign = sign,
                    is_multi_app = TRUE,
                    apps_manifest = apps_manifest,
                    verbose = verbose)

  # Install npm dependencies
  install_npm_dependencies(output_dir, verbose = verbose)

  # Build for platforms
  build_for_platforms(output_dir, platform, arch, sign = sign, verbose = verbose)

  return(fs::path_abs(output_dir))
}
