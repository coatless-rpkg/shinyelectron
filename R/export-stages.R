#' Resolve the platforms and architectures to build for
#'
#' The `platform` and `arch` arguments of [export()] win over
#' `build.platforms` and `build.architectures` in `_shinyelectron.yml`, which
#' win over the platform and architecture of the build machine. Each argument
#' replaces only its own list, and repeated values are dropped. The result is
#' checked as [build_electron_app()] checks its arguments, so an invalid value
#' stops the export before anything is converted or built.
#'
#' @param platform,arch Character vectors or `NULL`. The arguments.
#' @param config List. The effective configuration.
#' @return A list with the character vectors `platform` and `arch`, and
#'   `from_config`, the settings that supplied them (`"build.platforms"`,
#'   `"build.architectures"`, both or neither), for error messages.
#' @keywords internal
resolve_build_targets <- function(platform, arch, config) {
  from_config <- c(
    if (is.null(platform) && !is.null(config$build$platforms)) "build.platforms",
    if (is.null(arch) && !is.null(config$build$architectures)) "build.architectures"
  )
  platform <- unique(platform %||% config$build$platforms %||% detect_current_platform())
  arch <- unique(arch %||% config$build$architectures %||% detect_current_arch())
  validate_platform(platform)
  validate_arch(arch)
  list(platform = platform, arch = arch, from_config = from_config %||% character(0))
}

#' Stop when a macOS target is built on another system
#'
#' electron-builder makes macOS apps and their disk images only on macOS.
#' Elsewhere a `mac` build fails, and [build_for_platforms()] only reports
#' the failure, so [export()] would finish without an installer. It calls
#' this before anything is converted instead.
#'
#' @param platform Character vector. The resolved target platforms.
#' @param from_config Character vector. The settings that supplied the
#'   targets, from [resolve_build_targets()].
#' @return Invisibly `TRUE`. Stops with an error of class
#'   `shinyelectron_mac_host` when a target is `mac` and the build machine
#'   is not.
#' @keywords internal
check_build_host <- function(platform, from_config = character(0)) {
  host <- detect_current_platform()
  if (!"mac" %in% platform || identical(host, "mac")) {
    return(invisible(TRUE))
  }
  cli::cli_abort(c(
    "Cannot build the {.val mac} target on {.val {host}}: macOS apps build only on macOS.",
    "i" = if ("build.platforms" %in% from_config) {
      "{.field build.platforms} in {.file _shinyelectron.yml} lists {.val mac}."
    },
    "i" = "Build on a Mac, or leave {.val mac} out, for example with {.code platform = \"{host}\"}."
  ), class = "shinyelectron_mac_host")
}

#' Stop when a runtime strategy cannot build every target
#'
#' The `bundled` and `auto-download` strategies embed a runtime, or a
#' manifest for one, for a single platform and architecture, and it would
#' be packaged into every installer. A build that uses either one needs a
#' single target. [export()] checks this before anything is copied;
#' [build_electron_app()] and [build_multi_app()] check it again for
#' direct callers.
#'
#' @param strategies Character vector. The runtime strategy of the app, or
#'   of each app in a suite.
#' @param platform,arch Character vectors. The resolved targets.
#' @param apps List or `NULL`. A suite's `apps` entries, in the order of
#'   `strategies`, to name the app in the error.
#' @param from_config Character vector. The settings that supplied the
#'   targets, from [resolve_build_targets()].
#' @return Invisibly `TRUE`. Stops with an error of class
#'   `shinyelectron_single_target` otherwise.
#' @keywords internal
check_single_target <- function(strategies, platform, arch, apps = NULL,
                                from_config = character(0)) {
  single <- which(strategies %in% c("bundled", "auto-download"))
  if (length(single) == 0 || (length(platform) <= 1 && length(arch) <= 1)) {
    return(invisible(TRUE))
  }
  strategy <- strategies[[single[1]]]
  app_id <- apps[[single[1]]]$id
  # Name a setting only when it supplied more than one value.
  fields <- intersect(
    c(if (length(platform) > 1) "build.platforms",
      if (length(arch) > 1) "build.architectures"),
    from_config
  )
  cli::cli_abort(c(
    "The {.val {strategy}} strategy supports only one platform and architecture per build.",
    "i" = if (is.null(app_id)) {
      "It embeds a {.val {platform[1]}}/{.val {arch[1]}} runtime that would be packaged into every installer."
    } else {
      "App {.val {app_id}} embeds a single-platform runtime that would be packaged into every installer."
    },
    "i" = if (length(fields) > 0) {
      "The targets come from {.field {fields}} in {.file _shinyelectron.yml}."
    },
    "i" = "Build each target separately, or use the {.val system}, {.val container}, or {.val shinylive} strategy for multi-platform builds."
  ), class = "shinyelectron_single_target")
}

#' Convert a Shiny app to the shinylive format
#'
#' Dispatches to the R or Python shinylive converter based on language.
#' @param appdir Character. Source Shiny app directory.
#' @param destdir Character. Export destination.
#' @param app_type Character. `"r-shiny"` or `"py-shiny"`.
#' @param verbose Logical.
#' @return Character. Path to the converted shinylive app.
#' @keywords internal
convert_app_to_shinylive <- function(appdir, destdir, app_type, verbose = TRUE) {
  if (verbose) cli::cli_alert_info("Converting to shinylive format...")
  shinylive_dir <- fs::path(destdir, "shinylive-app")

  if (app_type == "r-shiny") {
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

  dep_info <- resolve_app_dependencies(appdir, app_type, runtime_strategy, config)
  if (!is.null(dep_info) && length(dep_info$packages) > 0) {
    if (verbose) {
      cli::cli_alert_info("Detected {length(dep_info$packages)} {dep_info$language} package dependencies")
      cli::cli_alert_info("Packages: {paste(dep_info$packages, collapse = ', ')}")
    }
    manifest <- generate_dependency_manifest(
      packages = dep_info$packages,
      language = dep_info$language,
      repos = dep_info$repos,
      index_urls = dep_info$index_urls,
      local_packages = local_r_package_names(config$dependencies$r$local_packages)
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
    version <- resolve_runtime_version("r", config)
    manifest <- generate_runtime_manifest(version = version,
                                          platform = resolved_platform,
                                          arch = resolved_arch)
    if (verbose) cli::cli_alert_info("Runtime manifest written for R {version}")
  } else {
    version <- resolve_runtime_version("python", config)
    pbs <- resolve_python_pbs(version)
    manifest <- generate_python_runtime_manifest(version = version,
                                                 platform = resolved_platform,
                                                 arch = resolved_arch,
                                                 release_date = pbs$release)
    if (verbose) cli::cli_alert_info("Runtime manifest written for Python {version}")
  }

  writeLines(manifest, fs::path(app_dir, "runtime-manifest.json"))
}
