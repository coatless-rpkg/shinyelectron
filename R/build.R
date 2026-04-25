#' Build Electron Application
#'
#' Builds a distributable Electron application from a converted Shiny app.
#' Creates platform-specific installers and executables.
#'
#' @param app_dir Character string. Path to the converted Shiny/shinylive application.
#' @param output_dir Character string. Path where the built Electron app will be saved.
#' @param app_name Character string. Name of the application. If NULL, uses the base name of app_dir.
#' @param app_type Character string. Language of the Shiny app: `"r-shiny"` or
#'   `"py-shiny"`. The legacy values `"r-shinylive"` / `"py-shinylive"` are
#'   accepted with a deprecation warning and translate to the canonical
#'   language plus `runtime_strategy = "shinylive"`.
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

    # Step 2.5: Embed R runtime for bundled strategy
    if (runtime_strategy == "bundled" && grepl("^r-", app_type)) {
      if (verbose) cli::cli_alert_info("Embedding R runtime for bundled strategy...")

      r_version <- config$r$version %||% NULL
      r_path <- install_r(
        version = r_version,
        platform = platform[1],
        arch = arch[1],
        verbose = verbose
      )

      # Copy runtime into the Electron app
      runtime_dest <- fs::path(output_dir, "runtime", "R")
      copy_dir_contents(r_path, runtime_dest)

      # Resolve symlinks that point outside the package directory.
      # Portable R may contain fontconfig symlinks pointing to system R,
      # which electron-builder refuses to package (security protection).
      runtime_files <- list.files(runtime_dest, recursive = TRUE,
                                  full.names = TRUE, all.files = TRUE)
      for (f in runtime_files) {
        if (nzchar(Sys.readlink(f))) {
          target <- Sys.readlink(f)
          abs_target <- normalizePath(f, mustWork = FALSE)
          if (file.exists(abs_target)) {
            file.remove(f)
            file.copy(abs_target, f, copy.date = TRUE)
          } else {
            # Dead symlink — remove it
            file.remove(f)
          }
        }
      }

      # Install packages using the BUNDLED portable R itself (not the cache,
      # and not system R). This ensures binary packages are linked against
      # matching dylibs AND are installed into the exact library the app
      # will load from at runtime.
      dep_manifest_path <- fs::path(output_dir, "src", "app", "dependencies.json")
      if (fs::file_exists(dep_manifest_path)) {
        dep_manifest <- jsonlite::fromJSON(dep_manifest_path, simplifyVector = FALSE)
        if (length(dep_manifest$packages) > 0 && dep_manifest$language == "r") {

          # Install into a SIBLING library directory (runtime_dest/library/),
          # NOT into portable-r-*/library/. On macOS, installing into the
          # bundled R's own library triggers hardened-runtime library
          # validation at dyn.load() time, causing segfaults on unsigned
          # CRAN binaries. The sibling-library layout avoids that; the
          # Electron runtime (native-r.js) prepends this path to .libPaths().
          lib_path <- fs::path(runtime_dest, "library")
          fs::dir_create(lib_path, recurse = TRUE)

          # Use the CACHED Rscript, not the bundled copy. The cached binary
          # has its original code signature intact; running the copied one
          # on macOS with --vanilla can interact oddly with hardened-runtime
          # library validation.
          bundled_rscript <- r_executable(
            version = r_version %||% r_latest_version(),
            platform = platform[1],
            arch = arch[1]
          )

          if (is.null(bundled_rscript) || !fs::file_exists(bundled_rscript)) {
            cli::cli_abort(c(
              "Could not locate the cached portable Rscript",
              "i" = "Try: {.code shinyelectron::install_r(force = TRUE)}"
            ))
          }

          if (verbose) cli::cli_alert_info("Installing packages with bundled R...")

          pkgs <- unlist(dep_manifest$packages)
          repos <- unlist(dep_manifest$repos)

          # Fetch the available-packages database once (avoids repeated
          # CRAN network calls during the same export session).
          avail_pkgs <- utils::available.packages(repos = repos)

          # Resolve full dependency tree
          all_deps <- tools::package_dependencies(
            pkgs, db = avail_pkgs,
            which = c("Depends", "Imports", "LinkingTo"),
            recursive = TRUE
          )
          all_pkgs <- unique(c(pkgs, unlist(all_deps)))

          # Skip packages already present in the bundled library. Portable-R
          # ships with base + recommended + a few extras; reinstalling them is
          # wasteful and, on Windows, tripped "cannot remove prior installation"
          # errors when antivirus held file handles on freshly-extracted DLLs.
          pre_installed <- list.dirs(lib_path, recursive = FALSE, full.names = FALSE)
          pre_installed <- pre_installed[nzchar(pre_installed)]
          all_pkgs <- setdiff(all_pkgs, pre_installed)

          if (length(all_pkgs) == 0) {
            if (verbose) cli::cli_alert_info("All dependencies already present in bundled R library")
          } else {
            if (verbose) {
              cli::cli_alert_info("Installing {length(all_pkgs)} package{?s} into bundled library")
            }

            pkg_str <- paste0("'", all_pkgs, "'", collapse = ", ")
            repo_str <- paste0("'", repos, "'", collapse = ", ")
            # Use the bundled library as both destination AND the only lib on
            # .libPaths — avoids install.packages getting confused by packages
            # the caller's R_LIBS_USER may have inherited.
            r_code <- sprintf(
              paste0(
                ".libPaths('%s'); ",
                "install.packages(c(%s), lib = '%s', repos = c(%s), ",
                "type = 'binary', dependencies = FALSE, quiet = TRUE)"
              ),
              gsub("\\\\", "/", lib_path),
              pkg_str,
              gsub("\\\\", "/", lib_path),
              repo_str
            )

            # Pre-session code didn't scrub env or pass --vanilla and worked
            # fine — the bundled library being a sibling (not the R's own
            # library) means R_LIBS_USER contamination doesn't override our
            # explicit lib_path argument to install.packages.
            result <- processx::run(
              bundled_rscript, c("-e", r_code),
              error_on_status = FALSE,
              echo = verbose,
              timeout = 600
            )

            # Verify every app-direct package is present in the bundled library
            # after install. A post-install check is far easier to diagnose
            # than "no package called 'htmltools'" from a running Shiny server.
            present <- c(pre_installed,
                         list.dirs(lib_path, recursive = FALSE, full.names = FALSE))
            missing_pkgs <- setdiff(pkgs, present)
            if (length(missing_pkgs) > 0) {
              cli::cli_abort(c(
                "Failed to install bundled R packages: {paste(missing_pkgs, collapse = ', ')}",
                "i" = "install.packages exit code: {result$status}",
                "x" = "stderr: {trimws(result$stderr %||% '')}"
              ))
            }

          }
        }
      }

      if (verbose) cli::cli_alert_success("Embedded R runtime")
    }

    # Embed Python runtime for bundled strategy
    if (runtime_strategy == "bundled" && grepl("^py-", app_type)) {
      if (verbose) cli::cli_alert_info("Embedding Python runtime for bundled strategy...")

      py_version <- config$python$version %||% "3.12.10"
      py_path <- install_python(
        version = py_version,
        platform = platform[1],
        arch = arch[1],
        verbose = verbose
      )

      runtime_dest <- fs::path(output_dir, "runtime", "Python")
      copy_dir_contents(py_path, runtime_dest)

      # Install packages using the BUNDLED Python (not system Python) so
      # C extensions match the bundled Python version's ABI
      bundled_python <- python_executable(py_version, platform[1], arch[1])
      if (is.null(bundled_python)) {
        # Fall back to searching the copied runtime
        bundled_python <- Sys.glob(fs::path(runtime_dest, "*", "python", "bin", "python3"))[1]
      }

      dep_manifest_path <- fs::path(output_dir, "src", "app", "dependencies.json")
      if (!is.null(bundled_python) && fs::file_exists(dep_manifest_path)) {
        dep_manifest <- jsonlite::fromJSON(dep_manifest_path, simplifyVector = FALSE)
        if (length(dep_manifest$packages) > 0 && dep_manifest$language == "python") {
          index_url <- unlist(dep_manifest$index_urls)[1] %||% "https://pypi.org/simple"
          pip_args <- c("-m", "pip", "install", "--only-binary", ":all:",
                       "-i", index_url,
                       "--target", fs::path(runtime_dest, "lib", "python", "site-packages"),
                       unlist(dep_manifest$packages))
          if (verbose) {
            cli::cli_alert_info("Installing Python packages using bundled Python...")
          }
          pip_result <- processx::run(
            bundled_python, pip_args,
            echo = verbose, spinner = verbose,
            error_on_status = FALSE, timeout = 600
          )
          if (pip_result$status != 0) {
            cli::cli_warn(c(
              "Failed to install some Python packages",
              "x" = "Error: {pip_result$stderr}"
            ))
          }
        }
      }

      if (verbose) cli::cli_alert_success("Embedded Python runtime")
    }

    # Prepare container configuration
    if (runtime_strategy == "container") {
      if (verbose) cli::cli_alert_info("Preparing container configuration...")

      engine <- detect_container_engine(config$container$engine)
      container_config_json <- generate_container_config(
        app_type = app_type,
        engine = engine %||% "docker",
        config = config,
        app_slug = slugify(app_name)
      )

      # Write container config for the backend to read
      container_config_dir <- fs::path(output_dir, "src", "app")
      fs::dir_create(container_config_dir, recurse = TRUE)
      writeLines(container_config_json,
                 fs::path(container_config_dir, "container-config.json"))

      if (verbose) cli::cli_alert_success("Container configuration prepared")
    }

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
