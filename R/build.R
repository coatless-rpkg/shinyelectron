#' Build Electron Application
#'
#' Builds a distributable Electron application from a converted Shiny app.
#' Creates platform-specific installers and executables.
#'
#' @param app_dir Character string. Path to the converted Shiny/shinylive application.
#' @param output_dir Character string. Path where the built Electron app will be saved.
#' @param app_name Character string. Name of the application. If NULL, uses the base name of app_dir.
#' @param app_type Character string. Language of the Shiny app: `"r-shiny"`
#'   (default) or `"py-shiny"`. Unlike `export()`, this function does **not**
#'   autodetect the language from source files -- the default `"r-shiny"` is
#'   used when `app_type` is not supplied. Supply `"py-shiny"` explicitly for
#'   Python Shiny applications. The legacy values `"r-shinylive"` /
#'   `"py-shinylive"` are accepted with a deprecation warning and translate to
#'   the canonical language plus `runtime_strategy = "shinylive"`.
#' @param runtime_strategy Character string. Runtime strategy: `"shinylive"`,
#'   `"bundled"`, `"system"`, `"auto-download"`, or `"container"`. Default
#'   `"shinylive"`.
#' @param platform Character vector. Target platforms: "win", "mac", "linux". If NULL, builds for current platform.
#' @param arch Character vector. Target architectures: "x64", "arm64". If NULL, uses current architecture.
#' @param icon Character string. Path to application icon file. Platform-specific format required.
#' @param sign Logical. Whether to enable code signing for the built application.
#'   Default is FALSE.
#' @param config List. Configuration from _shinyelectron.yml file (optional). Used for
#'   template variables like window dimensions, port, and app version.
#' @param overwrite Logical. Whether to overwrite existing output directory. Default is FALSE.
#' @param verbose Logical. Whether to display detailed progress information. Default is TRUE.
#'
#' @return Character string. Path to the built Electron application directory.
#'
#' @section Details:
#' This function creates a complete Electron application by:
#' \itemize{
#'   \item Setting up the Electron project structure
#'   \item Copying application files and templates
#'   \item Installing npm dependencies
#'   \item Building platform-specific distributables
#' }
#'
#' @examples
#' \dontrun{
#' # Build Electron app for current platform
#' build_electron_app(
#'   app_dir = "path/to/shinylive/app",
#'   output_dir = "path/to/electron/build",
#'   app_name = "My Shiny App",
#'   app_type = "r-shiny"
#' )
#'
#' # Build for multiple platforms
#' build_electron_app(
#'   app_dir = "path/to/app",
#'   output_dir = "path/to/build",
#'   app_name = "My App",
#'   app_type = "r-shiny",
#'   platform = c("win", "mac", "linux")
#' )
#' }
#'
#' @export
build_electron_app <- function(app_dir, output_dir, app_name = NULL, app_type = "r-shiny",
                               runtime_strategy = "shinylive", sign = FALSE,
                               platform = NULL, arch = NULL, icon = NULL,
                               config = NULL, overwrite = FALSE, verbose = TRUE) {

  # Validate inputs
  validate_directory_exists(app_dir, "Application directory")

  # Normalize legacy app_type values
  normalized <- normalize_app_type_arg(app_type, runtime_strategy)
  app_type <- normalized$app_type %||% app_type
  runtime_strategy <- normalized$runtime_strategy %||% runtime_strategy

  validate_app_type(app_type)
  validate_runtime_strategy(runtime_strategy)

  if (is.null(app_name)) {
    app_name <- basename(app_dir)
  }
  validate_app_name(app_name)

  if (verbose) {
    cli::cli_h1("Building Electron application")
    cli::cli_alert_info("App: {.val {app_name}}")
    cli::cli_alert_info("Type: {.val {app_type}}")
    cli::cli_alert_info("Source: {.path {app_dir}}")
    cli::cli_alert_info("Output: {.path {output_dir}}")
  }

  # Set up platform and architecture defaults
  if (is.null(platform)) {
    platform <- detect_current_platform()
  }
  if (is.null(arch)) {
    arch <- detect_current_arch()
  }

  validate_platform(platform)
  validate_arch(arch)

  # Bundled and auto-download native runtimes embed a single platform/arch
  # runtime (or manifest) that would be copied into every installer, so they
  # cannot target multiple platforms or architectures in one build.
  if (runtime_strategy %in% c("bundled", "auto-download") &&
      grepl("^(r|py)-", app_type) &&
      (length(platform) > 1 || length(arch) > 1)) {
    cli::cli_abort(c(
      "The {.val {runtime_strategy}} strategy supports only one platform and architecture per build.",
      "i" = "It embeds a {.val {platform[1]}}/{.val {arch[1]}} runtime that would be packaged into every installer.",
      "i" = "Build each target separately, or use the {.val system}, {.val container}, or {.val shinylive} strategy for multi-platform builds."
    ))
  }

  if (verbose) {
    cli::cli_alert_info("Platform(s): {.val {platform}}")
    cli::cli_alert_info("Architecture(s): {.val {arch}}")
  }

  # Check if output directory exists
  if (fs::dir_exists(output_dir)) {
    if (!overwrite) {
      cli::cli_abort(c(
        "Output directory already exists: {.path {output_dir}}",
        "i" = "Use {.code overwrite = TRUE} to overwrite existing directory"
      ))
    } else {
      if (verbose) cli::cli_alert_warning("Overwriting existing directory: {.path {output_dir}}")
      assert_safe_to_overwrite(output_dir)
      unlink(output_dir, recursive = TRUE)
    }
  }

  # Create output directory
  fs::dir_create(output_dir, recurse = TRUE)

  # Validate npm/node availability
  validate_node_npm()

  if (verbose) {
    pb <- cli::cli_progress_bar("Building Electron app", total = 6)
  }

  tryCatch({
    # Step 1: Setup Electron project structure
    if (verbose) cli::cli_progress_update(id = pb, set = 1)
    setup_electron_project(output_dir, app_name, app_type, verbose = verbose)

    # Step 2: Copy application files
    if (verbose) cli::cli_progress_update(id = pb, set = 2)
    copy_app_files(app_dir, output_dir, app_type,
                   runtime_strategy = runtime_strategy, verbose = verbose)

    # Step 2.5: Embed the native runtime for the bundled strategy. The embedding
    # helpers live in R/build-runtime.R (shared with the multi-app pipeline);
    # they own dependency-tree resolution and always embed the interpreter, even
    # when no packages are declared.
    dep_manifest_path <- fs::path(output_dir, "src", "app", "dependencies.json")

    if (runtime_strategy == "bundled" && grepl("^r-", app_type)) {
      packages <- character(0)
      repos <- NULL
      if (fs::file_exists(dep_manifest_path)) {
        dep_manifest <- jsonlite::fromJSON(dep_manifest_path, simplifyVector = FALSE)
        if (identical(dep_manifest$language, "r")) {
          packages <- unlist(dep_manifest$packages)
          repos <- unlist(dep_manifest$repos)
        }
      }
      embed_r_runtime(
        output_dir = output_dir,
        packages = packages,
        repos = repos,
        version = resolve_runtime_version("r", config),
        platform = platform[1],
        arch = arch[1],
        verbose = verbose
      )
    }

    if (runtime_strategy == "bundled" && grepl("^py-", app_type)) {
      packages <- character(0)
      index_urls <- NULL
      if (fs::file_exists(dep_manifest_path)) {
        dep_manifest <- jsonlite::fromJSON(dep_manifest_path, simplifyVector = FALSE)
        if (identical(dep_manifest$language, "python")) {
          packages <- unlist(dep_manifest$packages)
          index_urls <- unlist(dep_manifest$index_urls)
        }
      }
      embed_python_runtime(
        output_dir = output_dir,
        packages = packages,
        index_urls = index_urls,
        version = resolve_runtime_version("python", config),
        platform = platform[1],
        arch = arch[1],
        verbose = verbose
      )
    }

    # Container settings reach the backend via backend_config_json (inlined
    # into main.js by generate_template_variables()); no separate config file
    # is written here.

    # Step 3: Copy and process templates
    if (verbose) cli::cli_progress_update(id = pb, set = 3)
    process_templates(output_dir, app_name, app_type,
                      runtime_strategy = runtime_strategy,
                      icon = icon, config = config, sign = sign,
                      verbose = verbose)

    # Step 4: Install npm dependencies
    if (verbose) cli::cli_progress_update(id = pb, set = 4)
    install_npm_dependencies(output_dir, verbose = verbose)

    # Step 5: Build for target platforms
    if (verbose) cli::cli_progress_update(id = pb, set = 5)
    build_for_platforms(output_dir, platform, arch, sign = sign, verbose = verbose)

    # Step 6: Validate build output
    if (verbose) cli::cli_progress_update(id = pb, set = 6)
    validate_build_output(output_dir, platform)

    if (verbose) {
      cli::cli_progress_done(id = pb)
      cli::cli_alert_success("Successfully built Electron app: {.path {output_dir}}")
    }

    return(fs::path_abs(output_dir))

  }, error = function(e) {
    cli::cli_abort(c(
      "Failed to build Electron application",
      "x" = "Error: {e$message}"
    ), parent = e)
  })
}
