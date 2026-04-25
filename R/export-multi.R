#' Export multi-app Shiny suite as Electron application
#' @keywords internal
export_multi_app <- function(appdir, destdir, config,
                              runtime_strategy = NULL, sign = FALSE,
                              platform = NULL, arch = NULL, icon = NULL,
                              overwrite = FALSE, build = TRUE,
                              run_after = FALSE, open_after = FALSE,
                              verbose = TRUE) {

  app_name <- config$app$name %||% basename(appdir)

  # Normalize suite-level build.type (may be legacy) and resolve strategy
  raw_type <- config$build$type %||% "r-shiny"
  suite_normalized <- normalize_app_type_arg(raw_type, runtime_strategy %||% config$build$runtime_strategy)
  app_type <- suite_normalized$app_type %||% "r-shiny"
  runtime_strategy <- runtime_strategy %||% suite_normalized$runtime_strategy %||% config$build$runtime_strategy %||% "shinylive"

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
      this_strategy <- resolve_app_strategy(app_entry, config)

      if (verbose) cli::cli_alert_info("Processing app: {.val {app_entry$name}} ({this_type}, {this_strategy})")

      # Convert or copy based on strategy
      if (this_strategy == "shinylive") {
        if (this_type == "r-shiny") {
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
          resolve_app_dependencies(app_src, this_type, this_strategy, config)
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
        runtime_strategy = this_strategy,
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
    schema_version = MANIFEST_SCHEMA_VERSION,
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
