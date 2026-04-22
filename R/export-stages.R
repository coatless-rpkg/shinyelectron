#' Convert a Shiny app to the shinylive format
#'
#' Dispatches to the R or Python shinylive converter based on app type.
#' @param appdir Character. Source Shiny app directory.
#' @param destdir Character. Export destination.
#' @param app_type Character. One of SHINYLIVE_TYPES.
#' @param verbose Logical.
#' @return Character. Path to the converted shinylive app.
#' @keywords internal
convert_app_to_shinylive <- function(appdir, destdir, app_type, verbose = TRUE) {
  if (verbose) cli::cli_alert_info("Converting to shinylive format...")
  shinylive_dir <- fs::path(destdir, "shinylive-app")

  if (app_type == "r-shinylive") {
    convert_shiny_to_shinylive(appdir = appdir, output_dir = shinylive_dir,
                               overwrite = TRUE, verbose = verbose)
  } else {
    convert_py_to_shinylive(appdir = appdir, output_dir = shinylive_dir,
                            overwrite = TRUE, verbose = verbose)
  }
}

#' Prepare native Shiny app files for packaging
#'
#' Copies the app source into `destdir/shiny-app/`, detects package
#' dependencies, and writes runtime + dependency manifests that the
#' Electron backends will consume at launch time.
#'
#' @inheritParams convert_app_to_shinylive
#' @param runtime_strategy Character. Resolved runtime strategy.
#' @param platform,arch Character. Target platform / architecture.
#' @param config List. Effective merged configuration.
#' @return List with elements `converted_app` (path) and
#'   `dependencies` (NULL or the resolved dep info).
#' @keywords internal
prepare_native_app_files <- function(appdir, destdir, app_type, runtime_strategy,
                                     platform, arch, config, verbose = TRUE) {
  if (verbose) cli::cli_alert_info("Preparing application files...")

  app_copy_dir <- fs::path(destdir, "shiny-app")
  copy_dir_contents(appdir, app_copy_dir)

  dep_info <- resolve_app_dependencies(appdir, app_type, config)
  if (!is.null(dep_info) && length(dep_info$packages) > 0) {
    if (verbose) {
      cli::cli_alert_info("Detected {length(dep_info$packages)} {dep_info$language} package dependencies")
      cli::cli_alert_info("Packages: {paste(dep_info$packages, collapse = ', ')}")
    }
    manifest <- generate_dependency_manifest(
      packages = dep_info$packages,
      language = dep_info$language,
      repos = dep_info$repos,
      index_urls = dep_info$index_urls
    )
    writeLines(manifest, fs::path(app_copy_dir, "dependencies.json"))
  }

  if (runtime_strategy == "auto-download") {
    write_runtime_manifest(app_copy_dir, app_type, platform, arch, config,
                           verbose = verbose)
  }

  list(converted_app = app_copy_dir, dependencies = dep_info)
}

#' Write a runtime-manifest.json for the auto-download strategy
#' @keywords internal
write_runtime_manifest <- function(app_dir, app_type, platform, arch, config,
                                   verbose = TRUE) {
  resolved_platform <- platform[1] %||% detect_current_platform()
  resolved_arch <- arch[1] %||% detect_current_arch()

  if (grepl("^r-", app_type)) {
    version <- config$r$version %||% r_latest_version()
    manifest <- generate_runtime_manifest(version = version,
                                          platform = resolved_platform,
                                          arch = resolved_arch)
    if (verbose) cli::cli_alert_info("Runtime manifest written for R {version}")
  } else {
    version <- config$python$version %||% "3.12.10"
    manifest <- generate_python_runtime_manifest(version = version,
                                                 platform = resolved_platform,
                                                 arch = resolved_arch)
    if (verbose) cli::cli_alert_info("Runtime manifest written for Python {version}")
  }

  writeLines(manifest, fs::path(app_dir, "runtime-manifest.json"))
}
