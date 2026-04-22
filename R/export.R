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
  if (app_type %in% R_TYPES) {
    validate_shiny_app_structure(appdir)
  } else if (app_type %in% PY_TYPES) {
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
    if (app_type %in% NATIVE_TYPES) {
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
    # Step 1: Convert or stage application files
    if (app_type %in% SHINYLIVE_TYPES) {
      converted_app_dir <- convert_app_to_shinylive(
        appdir, destdir, app_type, verbose = verbose
      )
      result$converted_app <- converted_app_dir
    } else {
      prep <- prepare_native_app_files(
        appdir, destdir, app_type, runtime_strategy,
        platform, arch, config, verbose = verbose
      )
      converted_app_dir <- prep$converted_app
      result$converted_app <- prep$converted_app
      if (!is.null(prep$dependencies)) result$dependencies <- prep$dependencies
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
