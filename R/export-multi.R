#' Export multi-app Shiny suite as Electron application
#' @keywords internal
export_multi_app <- function(appdir, destdir, config,
                              app_name = NULL,
                              runtime_strategy = NULL, sign = FALSE,
                              platform = NULL, arch = NULL, icon = NULL,
                              overwrite = FALSE, build = TRUE,
                              run_after = FALSE, open_after = FALSE,
                              verbose = TRUE) {

  app_name <- app_name %||% config$app$name %||% basename(appdir)
  validate_app_name(app_name)

  # Validate the icon up front, matching the single-app path.
  if (!is.null(icon)) {
    validate_icon(icon, platform)
  }

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

  # Reject conflicting native runtime strategies within a language before
  # staging (e.g. one bundled and one auto-download R app in the suite).
  validate_suite_strategies(config$apps, config)

  # Create destination
  if (fs::dir_exists(destdir)) {
    if (!overwrite) {
      cli::cli_abort("Destination directory already exists: {.path {destdir}}")
    }
    assert_safe_to_overwrite(destdir)
    unlink(destdir, recursive = TRUE)
  }
  fs::dir_create(destdir, recurse = TRUE)
  created_destdir <- TRUE

  result <- list()

  result <- tryCatch({
    # Step 1: Process each app
    apps_dir <- fs::path(destdir, "apps")
    fs::dir_create(apps_dir)

    # Shinylive apps share ONE static site (one WebR/Pyodide asset tree) under
    # destdir/shinylive-site, each app exported into its own <id> subdir.
    shinylive_site_dir <- fs::path(destdir, "shinylive-site")

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

    # Accumulate the per-language UNION of DIRECT package sets. embed_*_runtime
    # resolves the recursive tree internally, so the union of direct sets is the
    # right input (R: each app's detected deps; Python: the shared suite list).
    r_union_packages <- character(0)
    r_union_repos <- NULL
    py_union_packages <- character(0)
    py_union_index_urls <- NULL

    for (app_entry in config$apps) {
      app_id <- app_entry$id
      app_src <- fs::path(appdir, app_entry$path)
      app_dest <- fs::path(apps_dir, app_id)
      this_type <- resolve_app_type(app_entry, config)
      this_strategy <- resolve_app_strategy(app_entry, config)

      if (verbose) cli::cli_alert_info("Processing app: {.val {app_entry$name}} ({this_type}, {this_strategy})")

      # Convert or copy based on strategy
      if (this_strategy == "shinylive") {
        # Additive shared-site export: each app lands at shinylive-site/<id>,
        # all sharing shinylive-site/shinylive/ (one runtime copy).
        if (this_type == "r-shiny") {
          convert_shiny_to_shinylive(appdir = app_src, output_dir = shinylive_site_dir,
                                     subdir = app_id, verbose = verbose)
        } else {
          convert_py_to_shinylive(appdir = app_src, output_dir = shinylive_site_dir,
                                  subdir = app_id, verbose = verbose)
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

          if (this_strategy == "bundled") {
            if (grepl("^r-", this_type)) {
              r_union_packages <- c(r_union_packages, unlist(dep_info$packages))
              if (is.null(r_union_repos)) r_union_repos <- dep_info$repos
            } else {
              py_union_packages <- c(py_union_packages, unlist(dep_info$packages))
              if (is.null(py_union_index_urls)) py_union_index_urls <- dep_info$index_urls
            }
          }
        }
      }

      # Build manifest entry (use NA for missing icon so jsonlite writes null, not {})
      app_icon <- if (is.null(app_entry$icon) || !nzchar(app_entry$icon %||% "")) NA else app_entry$icon
      serve <- if (this_strategy == "shinylive") {
        list(kind = "shinylive", site = "src/shinylive-site", subdir = app_id)
      } else if (this_strategy == "container") {
        list(kind = "container", path = paste0("src/apps/", app_id))
      } else {
        list(kind = "native", path = paste0("src/apps/", app_id),
             runtime_strategy = this_strategy)
      }
      apps_manifest <- c(apps_manifest, list(list(
        id = app_id,
        name = app_entry$name,
        description = app_entry$description %||% "",
        type = this_type,
        runtime_strategy = this_strategy,
        icon = app_icon,
        serve = serve
      )))
    }

    result$apps <- apps_manifest

    # Write the apps manifest into the staging root so it is emitted even when
    # build = FALSE (tests and tooling can read the serve descriptors without a
    # full Electron build). build_multi_app persists the same manifest into the
    # Electron output directory.
    manifest_data <- list(
      schema_version = MANIFEST_SCHEMA_VERSION,
      apps = apps_manifest,
      default_type = app_type,
      runtime_strategy = runtime_strategy
    )
    writeLines(
      jsonlite::toJSON(manifest_data, pretty = TRUE, auto_unbox = TRUE),
      fs::path(destdir, "apps-manifest.json")
    )

    # Step 2: Build Electron application
    if (build) {
      if (verbose) cli::cli_alert_info("Building Electron application...")

      electron_dir <- fs::path(destdir, "electron-app")

      # Write apps manifest for the Electron app
      fs::dir_create(electron_dir, recurse = TRUE)

      built_app_dir <- build_multi_app(
        apps_dir = apps_dir,
        shinylive_site_dir = shinylive_site_dir,
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
        verbose = verbose,
        r_packages = sort(unique(r_union_packages)),
        r_repos = r_union_repos,
        py_packages = sort(unique(py_union_packages)),
        py_index_urls = py_union_index_urls
      )

      result$electron_app <- built_app_dir
    }

    result
  }, error = function(e) {
    if (isTRUE(created_destdir) && fs::dir_exists(destdir)) {
      unlink(destdir, recursive = TRUE)
    }
    cli::cli_abort(c(
      "Failed to export multi-app suite",
      "x" = "Error: {e$message}"
    ), parent = e)
  })

  # The build output is committed past this point. Post-build actions must
  # never delete it, so they run OUTSIDE the cleanup tryCatch above.
  if (verbose) {
    cli::cli_alert_success("Successfully exported multi-app suite!")
    cli::cli_alert_info("Output: {.path {destdir}}")
  }

  # Run in dev mode if requested. A non-zero Electron exit must not destroy the
  # successful build, so failures warn rather than abort.
  if (run_after && build) {
    if (verbose) cli::cli_alert_info("Starting application in development mode...")
    tryCatch(
      run_electron_app(app_dir = result$electron_app, verbose = verbose),
      error = function(e) cli::cli_warn(c(
        "The application exited with an error (the build output was kept).",
        "i" = conditionMessage(e)
      ))
    )
  }

  if (open_after) {
    if (verbose) cli::cli_alert_info("Opening output directory...")
    tryCatch(
      utils::browseURL(destdir),
      error = function(e) cli::cli_warn(c(
        "Could not open the output directory (the build output was kept).",
        "i" = conditionMessage(e)
      ))
    )
  }

  result
}

#' Build multi-app Electron application
#' @keywords internal
build_multi_app <- function(apps_dir, output_dir, app_name,
                             apps_manifest, default_type,
                             runtime_strategy, sign, platform, arch,
                             icon, config, overwrite, verbose,
                             r_packages = NULL, r_repos = NULL,
                             py_packages = NULL, py_index_urls = NULL,
                             shinylive_site_dir = NULL) {

  if (is.null(platform)) platform <- detect_current_platform()
  if (is.null(arch)) arch <- detect_current_arch()

  validate_platform(platform)
  validate_arch(arch)

  # Resolve each app's type and runtime strategy once; the single-platform
  # guard, runtime embedding, and auto-download manifest writing all key off the
  # per-app resolved strategy rather than the suite-level scalar.
  app_types <- vapply(config$apps, function(a) resolve_app_type(a, config), character(1))
  app_strategies <- vapply(config$apps, function(a) resolve_app_strategy(a, config), character(1))

  # Bundled / auto-download native runtimes embed a single platform's runtime,
  # so a suite containing ANY such native app cannot target multiple platforms
  # or architectures in one build, regardless of the suite-level default.
  if ((length(platform) > 1 || length(arch) > 1) &&
      any(app_strategies %in% c("bundled", "auto-download"))) {
    offending_idx <- which(app_strategies %in% c("bundled", "auto-download"))[1]
    offending_id <- config$apps[[offending_idx]]$id
    offending_strategy <- app_strategies[offending_idx]
    cli::cli_abort(c(
      "The {.val {offending_strategy}} strategy supports only one platform and architecture per build.",
      "i" = "App {.val {offending_id}} embeds a single-platform runtime that would be packaged into every installer.",
      "i" = "Build each target separately, or use the {.val system}, {.val container}, or {.val shinylive} strategy for multi-platform builds."
    ))
  }

  validate_node_npm()

  fs::dir_create(output_dir, recurse = TRUE)

  # Setup project structure
  setup_electron_project(output_dir, app_name, default_type, verbose = verbose)

  # Copy native/container apps to src/apps/. Shinylive apps are NOT staged in
  # apps_dir (they live in shinylive_site_dir); we additionally skip any
  # shinylive id defensively so the per-app WASM duplication never reappears.
  src_apps_dir <- fs::path(output_dir, "src", "apps")
  fs::dir_create(src_apps_dir, recurse = TRUE)

  shinylive_ids <- vapply(apps_manifest, function(a) {
    if (!is.null(a$serve) && identical(a$serve$kind, "shinylive")) a$id else NA_character_
  }, character(1))
  shinylive_ids <- shinylive_ids[!is.na(shinylive_ids)]

  for (app_id_dir in list.dirs(apps_dir, recursive = FALSE, full.names = TRUE)) {
    app_id <- basename(app_id_dir)
    if (app_id %in% shinylive_ids) next
    copy_dir_contents(app_id_dir, fs::path(src_apps_dir, app_id))
  }

  # Copy the shared shinylive site once, preserving the single shinylive/ asset
  # tree shared by every sub-app.
  if (!is.null(shinylive_site_dir) && fs::dir_exists(shinylive_site_dir)) {
    copy_dir_contents(shinylive_site_dir, fs::path(output_dir, "src", "shinylive-site"))
  }

  # Embed native runtimes once per bundled language. Call unconditionally for a
  # bundled language even when the union package set is empty: shipping no
  # runtime/<lang> would break the suite-wide bundled detection in the backends.
  r_bundled  <- any(grepl("^r-",  app_types) & app_strategies == "bundled")
  py_bundled <- any(grepl("^py-", app_types) & app_strategies == "bundled")

  if (r_bundled) {
    if (verbose) cli::cli_alert_info("Embedding R runtime for bundled apps...")
    embed_r_runtime(
      output_dir = output_dir,
      packages = sort(unique(r_packages)),
      repos = r_repos %||% SHINYELECTRON_DEFAULTS$dependencies$r$repos,
      version = resolve_runtime_version("r", config),
      platform = platform[1],
      arch = arch[1],
      verbose = verbose
    )
  }
  if (py_bundled) {
    if (verbose) cli::cli_alert_info("Embedding Python runtime for bundled apps...")
    embed_python_runtime(
      output_dir = output_dir,
      packages = sort(unique(py_packages)),
      index_urls = py_index_urls %||% SHINYELECTRON_DEFAULTS$dependencies$python$index_urls,
      version = resolve_runtime_version("python", config),
      platform = platform[1],
      arch = arch[1],
      verbose = verbose
    )
  }

  # Auto-download native apps read runtime-manifest.json from their OWN app dir
  # (src/apps/<id>/runtime-manifest.json), so write one per such app.
  for (i in seq_along(config$apps)) {
    if (app_strategies[i] == "auto-download" && grepl("^(r|py)-", app_types[i])) {
      app_id <- config$apps[[i]]$id
      write_runtime_manifest(
        fs::path(src_apps_dir, app_id),
        app_types[i], platform, arch, config, verbose = verbose
      )
    }
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

  # Validate the assembled build output (mirrors the single-app pipeline).
  validate_build_output(output_dir, platform)

  return(fs::path_abs(output_dir))
}

#' Validate that each language uses a single native runtime strategy
#'
#' Native strategies (`system`, `bundled`, `auto-download`) share one backend
#' module and one suite-wide runtime detection per language, so a suite may
#' declare at most one distinct native strategy per language. `shinylive` and
#' `container` apps use their own backends and are exempt.
#'
#' @param apps List. `config$apps` entries.
#' @param config List. Full suite configuration.
#' @keywords internal
validate_suite_strategies <- function(apps, config) {
  native_strategies <- c("system", "bundled", "auto-download")
  suite_strategy <- config$build$runtime_strategy

  for (lang in c("r", "py")) {
    lang_pattern <- paste0("^", lang, "-")

    ids <- character(0)
    strategies <- character(0)
    for (app in apps) {
      if (!grepl(lang_pattern, resolve_app_type(app, config))) next
      strat <- resolve_app_strategy(app, config)
      if (!strat %in% native_strategies) next
      ids <- c(ids, app$id)
      strategies <- c(strategies, strat)
    }

    if (length(strategies) == 0) next

    distinct <- unique(strategies)
    if (length(distinct) > 1) {
      conflict_idx <- which(strategies != strategies[1])[1]
      cli::cli_abort(c(
        "Conflicting native runtime strategies for {.field {lang}-shiny} apps.",
        "x" = "App {.val {ids[1]}} uses {.val {strategies[1]}} but app {.val {ids[conflict_idx]}} uses {.val {strategies[conflict_idx]}}.",
        "i" = "All native apps of one language must share a single runtime strategy.",
        "i" = "Use {.val shinylive} or {.val container} for apps that need a different delivery."
      ), class = "shinyelectron_suite_strategy_conflict")
    }

    if (!is.null(suite_strategy) && suite_strategy %in% native_strategies &&
        !identical(suite_strategy, distinct)) {
      cli::cli_abort(c(
        "Suite-level {.field build.runtime_strategy} conflicts with a per-app strategy.",
        "x" = "Suite default is {.val {suite_strategy}} but app {.val {ids[1]}} resolves to {.val {strategies[1]}}.",
        "i" = "Set {.field build.runtime_strategy} to {.val {strategies[1]}} or remove the per-app override."
      ), class = "shinyelectron_suite_strategy_conflict")
    }
  }

  invisible(TRUE)
}
