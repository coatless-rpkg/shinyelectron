#' Utility functions for shinyelectron package
#'
#' @name utils
#' @keywords internal
NULL

#' Detect current platform
#'
#' @return Character string representing current platform ("win", "mac", or "linux")
#' @keywords internal
detect_current_platform <- function() {
  sysname <- Sys.info()[["sysname"]]
  switch(sysname,
         "Windows" = "win",
         "Darwin" = "mac",
         "Linux" = "linux",
         cli::cli_abort("Unsupported platform: {sysname}")
  )
}

#' Detect current architecture
#'
#' @return Character string representing current architecture ("x64" or "arm64")
#' @keywords internal
detect_current_arch <- function() {
  machine <- Sys.info()[["machine"]]
  if (grepl("arm|aarch", machine, ignore.case = TRUE)) {
    "arm64"
  } else {
    "x64"
  }
}

#' Get Node.js command
#'
#' Returns the path to the Node.js executable, preferring locally installed
#' versions managed by shinyelectron.
#'
#' @param prefer_local Logical. Whether to prefer the local shinyelectron-managed
#'   installation over the system installation. Default TRUE.
#' @return Character string path to node executable
#' @keywords internal
get_node_command <- function(prefer_local = TRUE) {
  if (prefer_local) {
    local_node <- nodejs_executable()
    if (!is.null(local_node) && fs::file_exists(local_node)) {
      return(local_node)
    }
  }

  # Fall back to system node
  if (Sys.info()[["sysname"]] == "Windows") {
    "node.exe"
  } else {
    "node"
  }
}

#' Get npm command
#'
#' Returns the path to the npm executable, preferring locally installed
#' versions managed by shinyelectron.
#'
#' @param prefer_local Logical. Whether to prefer the local shinyelectron-managed
#'   installation over the system installation. Default TRUE.
#' @return Character string path to npm executable
#' @keywords internal
get_npm_command <- function(prefer_local = TRUE) {
  if (prefer_local) {
    local_npm <- npm_executable()
    if (!is.null(local_npm) && fs::file_exists(local_npm)) {
      return(local_npm)
    }
  }

  # Fall back to system npm
  if (Sys.info()[["sysname"]] == "Windows") {
    "npm.cmd"
  } else {
    "npm"
  }
}

#' Set development environment variables
#'
#' @param port Integer port number
#' @param open_devtools Logical whether to open dev tools
#' @return Named list of old environment variables
#' @keywords internal
set_dev_environment <- function(port, open_devtools) {
  old_env <- list(
    ELECTRON_DEV_PORT = Sys.getenv("ELECTRON_DEV_PORT", NA),
    ELECTRON_DEV_TOOLS = Sys.getenv("ELECTRON_DEV_TOOLS", NA)
  )

  Sys.setenv(
    ELECTRON_DEV_PORT = as.character(port),
    ELECTRON_DEV_TOOLS = if (open_devtools) "true" else "false"
  )

  old_env
}

#' Restore environment variables
#'
#' @param old_env Named list of environment variables to restore
#' @keywords internal
restore_environment <- function(old_env) {
  for (var_name in names(old_env)) {
    old_value <- old_env[[var_name]]
    if (is.na(old_value)) {
      Sys.unsetenv(var_name)
    } else {
      do.call(Sys.setenv, stats::setNames(list(old_value), var_name))
    }
  }
}

#' Convert a display name to a path-safe slug
#'
#' Converts an application display name to a lowercase, hyphen-separated
#' string safe for use in file paths, container names, and npm package names.
#'
#' @param name Character string. The display name to slugify.
#' @return Character string. The slugified name.
#' @keywords internal
slugify <- function(name) {
  if (!nzchar(name)) {
    cli::cli_abort("App name cannot be empty")
  }
  slug <- tolower(name)
  slug <- gsub("[^a-z0-9]+", "-", slug)
  slug <- gsub("^-|-$", "", slug)
  # Collapse multiple consecutive dashes
  slug <- gsub("-{2,}", "-", slug)
  if (!nzchar(slug)) {
    cli::cli_abort("Cannot create an empty slug from input: {.val {name}}")
  }
  slug
}

#' Validate a slug string
#'
#' Checks that a slug contains only lowercase alphanumeric characters and
#' hyphens, and is not empty.
#'
#' @param slug Character string. The slug to validate.
#' @return Invisible TRUE if valid, otherwise aborts with an error.
#' @keywords internal
validate_slug <- function(slug) {
  if (is.null(slug) || !nzchar(slug)) {
    cli::cli_abort("App slug cannot be empty")
  }
  if (!grepl("^[a-z0-9]([a-z0-9-]*[a-z0-9])?$", slug)) {
    cli::cli_abort(c(
      "Invalid slug: {.val {slug}}",
      "i" = "Slug must contain only lowercase letters, numbers, and hyphens",
      "i" = "Slug must start and end with a letter or number"
    ))
  }
  invisible(TRUE)
}

#' Generate package.json content for Electron app
#'
#' Programmatically creates the package.json content based on the backend type
#' and configuration. This replaces the previous Whisker template approach
#' to avoid fragile JSON + Mustache comma handling.
#'
#' @param app_slug Character string. The slugified app name.
#' @param app_version Character string. The app version.
#' @param backend Character string. The backend module name without .js (e.g., "shinylive", "native-r").
#' @param config List. The effective configuration.
#' @param has_icon Logical. Whether an icon is provided.
#' @return Character string. The JSON content for package.json.
#' @keywords internal
generate_package_json <- function(app_slug, app_version, backend, config,
                                  has_icon = FALSE, sign = FALSE,
                                  is_multi_app = FALSE) {
  # Base structure
  pkg <- list(
    name = app_slug,
    version = app_version,
    description = paste0(app_slug, " - Shiny Electron App"),
    main = "main.js",
    scripts = list(
      electron = "electron .",
      build = "electron-builder",
      `build-all` = "electron-builder -mwl",
      `build-win` = "electron-builder --win",
      `build-mac` = "electron-builder --mac",
      `build-linux` = "electron-builder --linux",
      `build-win-x64` = "electron-builder --win --x64",
      `build-win-arm64` = "electron-builder --win --arm64",
      `build-mac-x64` = "electron-builder --mac --x64",
      `build-mac-arm64` = "electron-builder --mac --arm64",
      `build-linux-x64` = "electron-builder --linux --x64",
      `build-linux-arm64` = "electron-builder --linux --arm64"
    ),
    author = "",
    license = "AGPL (>=3)",
    devDependencies = list(
      electron = "^38.0.0",
      `electron-builder` = "^26.0.12"
    )
  )

  # Dependencies vary by backend
  deps <- list()
  if (backend == "shinylive") {
    deps[["express"]] <- "^5.1.0"
    deps[["serve-static"]] <- "^2.2.0"
  }

  # Auto-update dependencies
  updates_enabled <- isTRUE(config$updates$enabled)
  if (updates_enabled) {
    deps[["electron-updater"]] <- "^6.3.9"
    deps[["electron-log"]] <- "^5.2.4"
  }

  if (length(deps) > 0) {
    pkg$dependencies <- deps
  }

  # Build configuration
  build_config <- list(
    appId = config$installer$app_id %||% paste0("com.shinyelectron.", app_slug),
    productName = app_slug,
    directories = list(output = "dist")
  )

  # Publish config for auto-updates
  if (updates_enabled) {
    publish <- list(provider = config$updates$provider %||% "github")
    if (!is.null(config$updates$github$owner)) {
      publish$owner <- config$updates$github$owner
    }
    if (!is.null(config$updates$github$repo)) {
      publish$repo <- config$updates$github$repo
    }
    build_config$publish <- publish
  }

  # Files to include
  files <- c("main.js", "lifecycle.html", "preload.js",
             "src/**/*", "assets/**/*", "node_modules/**/*", "backends/**/*",
             "dockerfiles/**/*", "runtime/**/*")
  if (is_multi_app) {
    files <- c(files, "src/apps/**/*", "apps-manifest.json", "launcher.html")
  }
  build_config$files <- files

  # Unpack app files from ASAR so native R/Python/container backends
  # can access them on the real filesystem
  if (backend != "shinylive" || is_multi_app) {
    unpack <- list("src/app/**/*", "backends/**/*", "dockerfiles/**/*", "runtime/**/*")
    if (is_multi_app) {
      unpack <- c(unpack, "src/apps/**/*", "apps-manifest.json")
    }
    build_config$asarUnpack <- unpack
  }

  # Platform targets
  win_config <- list(target = "nsis")
  mac_config <- list(target = "dmg")
  linux_config <- list(target = "AppImage")

  if (has_icon) {
    win_config$icon <- "assets/icon.ico"
    mac_config$icon <- "assets/icon.icns"
    linux_config$icon <- "assets/icon.png"
  }

  # Code signing configuration
  if (sign) {
    signing <- config$signing %||% SHINYELECTRON_DEFAULTS$signing

    # macOS signing
    if (!is.null(signing$mac$identity)) {
      mac_config$identity <- signing$mac$identity
    }
    if (isTRUE(signing$mac$notarize) && !is.null(signing$mac$team_id)) {
      mac_config$notarize <- list(teamId = signing$mac$team_id)
    }

    # Windows signing
    if (!is.null(signing$win$certificate_file)) {
      win_config$certificateFile <- signing$win$certificate_file
      win_config$signingHashAlgorithms <- list("sha256")
    }
  } else {
    # Explicitly disable signing
    mac_config$identity <- NULL
  }

  if (!is.null(config$installer$license_file)) {
    win_config$license <- config$installer$license_file
  }

  if (!is.null(config$installer$one_click)) {
    build_config$nsis <- list(oneClick = config$installer$one_click)
  }

  build_config$win <- win_config
  build_config$mac <- mac_config
  build_config$linux <- linux_config

  pkg$build <- build_config

  jsonlite::toJSON(pkg, pretty = TRUE, auto_unbox = TRUE)
}

#' Determine the backend module filename for an app type and runtime strategy
#'
#' @param app_type Character string. The app type.
#' @param runtime_strategy Character string. The resolved runtime strategy.
#' @return Character string. The backend module filename (e.g., "shinylive.js").
#' @keywords internal
resolve_backend_module <- function(app_type, runtime_strategy) {
  switch(runtime_strategy,
    "shinylive" = "shinylive.js",
    "system" = , "bundled" = , "auto-download" = {
      if (grepl("^r-", app_type)) "native-r.js" else "native-py.js"
    },
    "container" = "container.js",
    cli::cli_abort("Unknown runtime strategy: {.val {runtime_strategy}}")
  )
}

#' Check if a backend requires Express dependencies
#'
#' @param backend_module Character string. The backend module filename.
#' @return Logical.
#' @keywords internal
backend_needs_express <- function(backend_module) {
  backend_module == "shinylive.js"
}

#' Run a command safely and return the result
#'
#' Wraps processx::run with consistent error handling. Returns a list
#' with status, stdout, and stderr. Never throws — failures are
#' indicated by a non-zero status.
#'
#' @param command Character command to run.
#' @param args Character vector of arguments.
#' @param timeout Numeric timeout in seconds. Default 30.
#' @return List with status, stdout, stderr.
#' @keywords internal
run_command_safe <- function(command, args = character(), timeout = 30) {
  tryCatch(
    processx::run(command, args, error_on_status = FALSE, timeout = timeout),
    error = function(e) list(status = 1L, stdout = "", stderr = e$message)
  )
}

#' Setup Electron project structure
#'
#' @param output_dir Character path to output directory
#' @param app_name Character application name
#' @param app_type Character application type
#' @param verbose Logical whether to show progress
#' @keywords internal
setup_electron_project <- function(output_dir, app_name, app_type, verbose = TRUE) {
  if (verbose) {
    cli::cli_alert_info("Setting up Electron project structure...")
  }

  # Create necessary directories
  dirs_to_create <- c("src", "assets", "build")
  for (dir in dirs_to_create) {
    fs::dir_create(fs::path(output_dir, dir), recurse = TRUE)
  }

  if (verbose) {
    cli::cli_alert_success("Created project structure")
  }
}

#' Locate Rscript inside a bundled portable-R runtime directory
#'
#' The portable-r distribution extracts to a subdirectory named
#' `portable-r-<version>-<os>-<arch>/`. Rscript lives at
#' `<subdir>/bin/Rscript[.exe]`. Searches for that layout first, then falls
#' back to a flat layout in case a future portable build drops the subdir.
#'
#' @param runtime_dir Character path to `runtime/R` inside the Electron app.
#' @return Character path to Rscript, or NULL if not found.
#' @keywords internal
find_bundled_rscript <- function(runtime_dir) {
  rscript_name <- if (detect_current_platform() == "win") "Rscript.exe" else "Rscript"

  # Prefer subdirectory layout (portable-r-*/bin/Rscript)
  subdirs <- list.dirs(runtime_dir, recursive = FALSE, full.names = TRUE)
  for (sub in subdirs) {
    candidate <- fs::path(sub, "bin", rscript_name)
    if (fs::file_exists(candidate)) return(candidate)
  }

  # Fallback: flat layout
  flat <- fs::path(runtime_dir, "bin", rscript_name)
  if (fs::file_exists(flat)) return(flat)

  NULL
}

#' Copy the top-level contents of one directory into another
#'
#' `fs::dir_copy(src, dst)` has different semantics across platforms and fs
#' versions: on some it creates `dst` and copies the contents of `src` into it,
#' on others it creates `dst/basename(src)/...`. This helper forces the
#' "copy contents into target" semantics by creating a fresh, empty `dst` and
#' then copying each top-level entry from `src` into it with base R.
#'
#' @param src Character path to the source directory.
#' @param dst Character path to the destination directory. Created if absent;
#'   wiped if present.
#' @return Invisible `dst`.
#' @keywords internal
copy_dir_contents <- function(src, dst) {
  if (fs::dir_exists(dst)) unlink(dst, recursive = TRUE)
  fs::dir_create(dst, recurse = TRUE)

  entries <- list.files(src, all.files = TRUE, no.. = TRUE, full.names = TRUE)
  if (length(entries) == 0) return(invisible(dst))

  ok <- file.copy(entries, dst, recursive = TRUE, overwrite = TRUE, copy.date = TRUE)
  if (!all(ok)) {
    failed <- entries[!ok]
    cli::cli_abort(c(
      "Failed to copy directory contents",
      "i" = "From: {.path {src}}",
      "i" = "To:   {.path {dst}}",
      "x" = "Could not copy: {paste(basename(failed), collapse = ', ')}"
    ))
  }
  invisible(dst)
}

#' Copy application files to Electron project
#'
#' @param app_dir Character source app directory
#' @param output_dir Character destination directory
#' @param app_type Character application type
#' @param verbose Logical whether to show progress
#' @keywords internal
copy_app_files <- function(app_dir, output_dir, app_type, verbose = TRUE) {
  if (verbose) {
    cli::cli_alert_info("Copying application files...")
  }

  dest_app_dir <- fs::path(output_dir, "src", "app")
  copy_dir_contents(app_dir, dest_app_dir)

  # Sanity check: for native Shiny apps, confirm the entrypoint made it across.
  # Catches copy-layout bugs at build time rather than at runtime inside Electron.
  entry_files <- switch(app_type,
    "r-shiny" = c("app.R", "server.R", "ui.R"),
    "py-shiny" = "app.py",
    NULL  # shinylive types validate their own output
  )
  if (!is.null(entry_files)) {
    found <- any(fs::file_exists(fs::path(dest_app_dir, entry_files)))
    if (!found) {
      cli::cli_abort(c(
        "Application files were copied but no Shiny entrypoint was found",
        "i" = "Expected one of: {paste(entry_files, collapse = ', ')}",
        "x" = "In: {.path {dest_app_dir}}"
      ))
    }
  }

  if (verbose) {
    cli::cli_alert_success("Copied application files")
  }
}

#' Process and copy Electron templates
#'
#' Assembles the Electron app from the shared shell template and the appropriate
#' backend module. Renders Whisker templates and generates package.json
#' programmatically.
#'
#' @param output_dir Character destination directory
#' @param app_name Character application display name
#' @param app_type Character application type
#' @param runtime_strategy Character resolved runtime strategy
#' @param icon Character path to icon file or NULL
#' @param config List of configuration values from config file (optional)
#' @param verbose Logical whether to show progress
#' @keywords internal
process_templates <- function(output_dir, app_name, app_type,
                              runtime_strategy = "shinylive",
                              icon = NULL, config = NULL, sign = FALSE,
                              is_multi_app = FALSE, apps_manifest = NULL,
                              verbose = TRUE) {
  if (verbose) {
    cli::cli_alert_info("Processing Electron templates...")
  }

  app_slug <- config$app$slug %||% slugify(app_name)
  validate_slug(app_slug)

  backend_module <- resolve_backend_module(app_type, runtime_strategy)

  # Read brand.yml for visual customization
  brand <- read_brand_yml(fs::path(output_dir, "src", "app"))
  # For multi-app, try reading from first app if src/app doesn't exist
  if (is.null(brand) && is_multi_app && !is.null(apps_manifest) && length(apps_manifest) > 0) {
    first_app_path <- fs::path(output_dir, apps_manifest[[1]]$path)
    if (fs::dir_exists(first_app_path)) {
      brand <- read_brand_yml(first_app_path)
    }
  }

  # Step 1: Copy and render shared templates (main.js, lifecycle.html, preload.js)
  shared_dir <- system.file("electron", "shared", package = "shinyelectron")
  if (!fs::dir_exists(shared_dir)) {
    cli::cli_abort("Shared template directory not found at {.path {shared_dir}}")
  }

  # Build template variables
  backend_config <- list(
    runtime_strategy = runtime_strategy,
    app_type = app_type,
    app_slug = app_slug,
    port_retry_count = config$lifecycle$port_retry_count %||%
      SHINYELECTRON_DEFAULTS$lifecycle$port_retry_count
  )

  template_vars <- list(
    app_name = app_name,
    app_slug = app_slug,
    app_type = app_type,
    app_version = config$app$version %||% SHINYELECTRON_DEFAULTS$app_version,
    has_icon = !is.null(icon),
    window_width = config$window$width %||% SHINYELECTRON_DEFAULTS$window_width,
    window_height = config$window$height %||% SHINYELECTRON_DEFAULTS$window_height,
    server_port = config$server$port %||% SHINYELECTRON_DEFAULTS$server_port,
    backend_module = backend_module,
    backend_config_json = jsonlite::toJSON(backend_config, auto_unbox = TRUE),

    # Brand variables (from _brand.yml or defaults)
    brand_primary = brand$color$primary %||% "#2563eb",
    brand_background = brand$color$background %||% "#f8fafc",
    brand_font = brand$typography$base$family %||% "",
    app_name_initial = substr(app_name, 1, 1),

    # Lifecycle variables
    shutdown_timeout = config$lifecycle$shutdown_timeout %||%
      SHINYELECTRON_DEFAULTS$lifecycle$shutdown_timeout,
    port_retry_count = config$lifecycle$port_retry_count %||%
      SHINYELECTRON_DEFAULTS$lifecycle$port_retry_count,

    # System tray settings
    tray_enabled = config$tray$enabled %||% SHINYELECTRON_DEFAULTS$tray$enabled,
    minimize_to_tray = config$tray$minimize_to_tray %||% SHINYELECTRON_DEFAULTS$tray$minimize_to_tray,
    close_to_tray = config$tray$close_to_tray %||% SHINYELECTRON_DEFAULTS$tray$close_to_tray,
    tray_tooltip = config$tray$tooltip %||% app_name,
    tray_icon = config$tray$icon,

    # Menu settings
    menu_enabled = config$menu$enabled %||% SHINYELECTRON_DEFAULTS$menu$enabled,
    menu_template = config$menu$template %||% SHINYELECTRON_DEFAULTS$menu$template,
    show_dev_tools = config$menu$show_dev_tools %||% SHINYELECTRON_DEFAULTS$menu$show_dev_tools,
    help_url = config$menu$help_url %||% "",

    # Auto-update settings
    updates_enabled = config$updates$enabled %||% SHINYELECTRON_DEFAULTS$updates$enabled,
    update_provider = config$updates$provider %||% SHINYELECTRON_DEFAULTS$updates$provider,
    check_on_startup = config$updates$check_on_startup %||% SHINYELECTRON_DEFAULTS$updates$check_on_startup,
    auto_download = config$updates$auto_download %||% SHINYELECTRON_DEFAULTS$updates$auto_download,
    auto_install = config$updates$auto_install %||% SHINYELECTRON_DEFAULTS$updates$auto_install,
    update_owner = config$updates$github$owner %||% "",
    update_repo = config$updates$github$repo %||% "",

    # Splash screen settings
    splash_background = config$splash$background %||% SHINYELECTRON_DEFAULTS$splash$background,
    splash_text = config$splash$text %||% SHINYELECTRON_DEFAULTS$splash$text,
    splash_text_color = config$splash$text_color %||% SHINYELECTRON_DEFAULTS$splash$text_color,
    has_splash_image = !is.null(config$splash$image),
    splash_image = if (!is.null(config$splash$image)) "assets/splash-image.png" else "",

    # Preloader settings
    preloader_style = config$preloader$style %||% SHINYELECTRON_DEFAULTS$preloader$style,
    preloader_message = config$preloader$message %||% SHINYELECTRON_DEFAULTS$preloader$message,
    preloader_background = config$preloader$background %||% SHINYELECTRON_DEFAULTS$preloader$background,

    # Custom lifecycle HTML
    has_custom_splash = !is.null(config$lifecycle$custom_splash_html),
    custom_splash_html = config$lifecycle$custom_splash_html %||% "",
    has_custom_error = !is.null(config$lifecycle$custom_error_html),
    custom_error_html = config$lifecycle$custom_error_html %||% "",

    # Logging
    log_level = config$app$log_level %||% SHINYELECTRON_DEFAULTS$logging$log_level,
    has_log_dir = !is.null(config$app$log_dir),
    log_dir = config$app$log_dir %||% "",

    # Menu template
    menu_minimal = identical(config$menu$template %||% "default", "minimal"),

    # Multi-app
    is_multi_app = is_multi_app,
    apps_json = if (is_multi_app) jsonlite::toJSON(apps_manifest, auto_unbox = TRUE) else "[]"
  )

  # Render shared template files with Whisker
  shared_files <- list.files(shared_dir, recursive = TRUE, full.names = TRUE)
  for (template_file in shared_files) {
    template_content <- readLines(template_file, warn = FALSE)
    template_content <- paste(template_content, collapse = "\n")
    processed_content <- whisker::whisker.render(template_content, template_vars)

    rel_path <- fs::path_rel(template_file, shared_dir)
    output_path <- fs::path(output_dir, rel_path)

    output_parent <- dirname(output_path)
    if (!fs::dir_exists(output_parent)) {
      fs::dir_create(output_parent, recurse = TRUE)
    }
    writeLines(processed_content, output_path)
  }

  # Step 2: Copy the appropriate backend module
  backends_dir <- system.file("electron", "backends", package = "shinyelectron")
  backend_src <- fs::path(backends_dir, backend_module)
  if (!fs::file_exists(backend_src)) {
    cli::cli_abort("Backend module not found: {.path {backend_src}}")
  }

  backend_dest_dir <- fs::path(output_dir, "backends")
  fs::dir_create(backend_dest_dir, recurse = TRUE)
  fs::file_copy(backend_src, fs::path(backend_dest_dir, backend_module))

  # For multi-app, copy ALL backend modules (apps may have different types)
  if (is_multi_app) {
    all_backends <- c("shinylive.js", "native-r.js", "native-py.js", "container.js")
    for (b in all_backends) {
      b_src <- fs::path(backends_dir, b)
      if (fs::file_exists(b_src)) {
        fs::file_copy(b_src, fs::path(backend_dest_dir, b), overwrite = TRUE)
      }
    }
  }

  # Copy shared utils.js -- all backends need it (shinylive uses findAvailablePort)
  utils_src <- fs::path(backends_dir, "utils.js")
  if (fs::file_exists(utils_src)) {
    fs::file_copy(utils_src, fs::path(backend_dest_dir, "utils.js"))
  }

  # Copy dependency-checker.js -- native backends (r-shiny, py-shiny) require it
  dep_checker_src <- fs::path(backends_dir, "dependency-checker.js")
  if (fs::file_exists(dep_checker_src)) {
    fs::file_copy(dep_checker_src, fs::path(backend_dest_dir, "dependency-checker.js"))
  }

  # Copy runtime-downloader.js -- auto-download strategy requires it
  rt_dl_src <- fs::path(backends_dir, "runtime-downloader.js")
  if (fs::file_exists(rt_dl_src)) {
    fs::file_copy(rt_dl_src, fs::path(backend_dest_dir, "runtime-downloader.js"))
  }

  # Copy Dockerfiles for container strategy and bake in app dependencies
  if (runtime_strategy == "container") {
    dockerfile_name <- if (grepl("^r-", app_type)) "r-shiny" else "py-shiny"
    dockerfile_src <- system.file("dockerfiles", dockerfile_name,
                                   package = "shinyelectron")

    if (fs::dir_exists(dockerfile_src)) {
      dockerfile_dest <- fs::path(output_dir, "dockerfiles")
      fs::dir_create(dockerfile_dest, recurse = TRUE)
      for (f in list.files(dockerfile_src, full.names = TRUE)) {
        fs::file_copy(f, fs::path(dockerfile_dest, basename(f)), overwrite = TRUE)
      }

      # Append app-specific dependencies to the Dockerfile
      # This bakes them into the image at build time (fast launch, no runtime compilation)
      dep_manifest <- fs::path(output_dir, "src", "app", "dependencies.json")
      if (fs::file_exists(dep_manifest)) {
        deps <- jsonlite::fromJSON(dep_manifest, simplifyVector = FALSE)
        pkgs <- unlist(deps$packages)
        if (length(pkgs) > 0) {
          dockerfile_path <- fs::path(dockerfile_dest, "Dockerfile")
          dockerfile_lines <- readLines(dockerfile_path)

          if (deps$language == "r") {
            # Try apt packages first (r-cran-*), fall back to install.packages
            apt_pkgs <- paste0("r-cran-", tolower(pkgs))
            apt_line <- paste0("RUN apt-get update && apt-get install -y --no-install-recommends ",
                              paste(apt_pkgs, collapse = " "),
                              " || R -e \"install.packages(c(",
                              paste0("'", pkgs, "'", collapse = ", "),
                              "))\" && rm -rf /var/lib/apt/lists/*")
            dockerfile_lines <- c(dockerfile_lines, "", "# App-specific R packages", apt_line)
          } else if (deps$language == "python") {
            pip_line <- paste0("RUN pip install --no-cache-dir ", paste(pkgs, collapse = " "))
            dockerfile_lines <- c(dockerfile_lines, "", "# App-specific Python packages", pip_line)
          }

          writeLines(dockerfile_lines, dockerfile_path)
        }
      }

      if (verbose) {
        cli::cli_alert_success("Copied Dockerfile for container strategy")
      }
    } else {
      cli::cli_warn("Dockerfile not found for app type: {.val {dockerfile_name}}")
    }
  }

  # Copy and render launcher.html for multi-app
  if (is_multi_app) {
    launcher_src <- system.file("electron", "shared", "launcher.html", package = "shinyelectron")
    if (fs::file_exists(launcher_src)) {
      launcher_content <- readLines(launcher_src, warn = FALSE)
      launcher_content <- paste(launcher_content, collapse = "\n")
      processed_launcher <- whisker::whisker.render(launcher_content, template_vars)
      writeLines(processed_launcher, fs::path(output_dir, "launcher.html"))
    }
  }

  # Step 3: Generate package.json programmatically
  package_json <- generate_package_json(
    app_slug = app_slug,
    app_version = config$app$version %||% SHINYELECTRON_DEFAULTS$app_version,
    backend = gsub("\\.js$", "", backend_module),
    config = config,
    has_icon = !is.null(icon),
    sign = sign,
    is_multi_app = is_multi_app
  )
  writeLines(package_json, fs::path(output_dir, "package.json"))

  # Step 4: Copy icon if provided
  if (!is.null(icon)) {
    icon_ext <- tools::file_ext(icon)
    icon_dest <- fs::path(output_dir, "assets", paste0("icon.", icon_ext))
    fs::file_copy(icon, icon_dest, overwrite = TRUE)
  }

  # Copy splash image if provided
  splash_image <- config$splash$image
  if (!is.null(splash_image) && file.exists(splash_image)) {
    splash_dest <- fs::path(output_dir, "assets", "splash-image.png")
    fs::file_copy(splash_image, splash_dest, overwrite = TRUE)
  }

  # Copy tray icon if provided (separate from app icon)
  tray_icon <- config$tray$icon
  if (!is.null(tray_icon) && file.exists(tray_icon)) {
    tray_dest <- fs::path(output_dir, "assets", basename(tray_icon))
    fs::file_copy(tray_icon, tray_dest, overwrite = TRUE)
  }

  if (verbose) {
    cli::cli_alert_success("Processed Electron templates")
  }
}

#' Install npm dependencies
#'
#' @param output_dir Character Electron project directory
#' @param verbose Logical whether to show progress
#' @keywords internal
install_npm_dependencies <- function(output_dir, verbose = TRUE) {
  if (verbose) {
    cli::cli_alert_info("Installing npm dependencies...")
  }

  # Run npm install
  result <- processx::run(
    command = get_npm_command(),
    args = c("install"),
    wd = output_dir,
    echo = verbose,
    spinner = verbose,
    error_on_status = FALSE
  )

  if (result$status != 0) {
    cli::cli_abort(c(
      "Failed to install npm dependencies",
      "x" = "Command: npm install",
      "x" = "Exit code: {result$status}",
      "x" = "Error: {result$stderr}",
      "",
      "i" = "Common causes:",
      "i" = "1. Node.js not properly installed",
      "i" = "2. Network connection issues",
      "i" = "3. npm cache corruption",
      "",
      "i" = "Try running: {.code shinyelectron::sitrep_electron_system()}",
      "i" = "Or clear npm cache: {.code npm cache clean --force}"
    ))
  }

  if (verbose) {
    cli::cli_alert_success("Installed npm dependencies")
  }
}


#' Build for target platforms
#'
#' @param output_dir Character Electron project directory
#' @param platform Character vector of target platforms
#' @param arch Character vector of target architectures
#' @param verbose Logical whether to show progress
#' @keywords internal
build_for_platforms <- function(output_dir, platform, arch, sign = FALSE, verbose = TRUE) {
  if (verbose) {
    cli::cli_alert_info("Building for platforms: {paste(platform, collapse = ', ')}")
  }

  # Check package.json exists and has necessary scripts
  package_json_path <- fs::path(output_dir, "package.json")
  if (!fs::file_exists(package_json_path)) {
    cli::cli_abort("No package.json found in: {.path {output_dir}}")
  }

  package_json <- jsonlite::fromJSON(package_json_path, simplifyVector = FALSE)
  available_scripts <- names(package_json$scripts %||% list())

  if (verbose) {
    cli::cli_alert_info("Available npm scripts: {paste(available_scripts, collapse = ', ')}")
  }

  # Prevent auto-discovery of signing certificates for unsigned builds
  if (!isTRUE(sign)) {
    old_csc <- Sys.getenv("CSC_IDENTITY_AUTO_DISCOVERY", NA)
    Sys.setenv(CSC_IDENTITY_AUTO_DISCOVERY = "false")
    on.exit({
      if (is.na(old_csc)) {
        Sys.unsetenv("CSC_IDENTITY_AUTO_DISCOVERY")
      } else {
        Sys.setenv(CSC_IDENTITY_AUTO_DISCOVERY = old_csc)
      }
    }, add = TRUE)
  }

  # Build for each platform/arch combination
  for (p in platform) {
    for (a in arch) {
      target <- paste0(p, "-", a)

      if (verbose) {
        cli::cli_alert_info("Building for {target}...")
      }

      # Try specific platform-arch script first
      build_script <- paste0("build-", p, "-", a)

      if (build_script %in% available_scripts) {
        result <- processx::run(
          command = get_npm_command(),
          args = c("run", build_script),
          wd = output_dir,
          echo = FALSE,
          spinner = verbose,
          cleanup_tree = TRUE,
          windows_hide_window = TRUE,
          error_on_status = FALSE
        )

        # Report key build stages from electron-builder output
        if (verbose && nzchar(result$stderr)) {
          lines <- strsplit(result$stderr, "\n")[[1]]
          for (line in lines) {
            line <- trimws(line)
            if (grepl("^\\s*\u2022\\s*packaging", line)) {
              cli::cli_alert_info("Packaging application...")
            } else if (grepl("^\\s*\u2022\\s*building\\s+target", line)) {
              cli::cli_alert_info("Creating installer...")
            } else if (grepl("^\\s*\u2022\\s*signing", line) && !grepl("signtool", line)) {
              cli::cli_alert_info("Signing application...")
            }
          }
        }

        if (result$status == 0) {
          if (verbose) cli::cli_alert_success("Built for {target}")
          next
        } else {
          if (verbose) cli::cli_alert_warning("Specific script {build_script} failed: {result$stderr}")
        }
      } else {
        if (verbose) cli::cli_alert_info("Script {build_script} not found, trying platform-only build")
      }

      # Fallback to platform-only build
      platform_script <- paste0("build-", p)

      if (platform_script %in% available_scripts) {
        if (verbose) {
          cli::cli_alert_info("Trying fallback build for {p}...")
        }

        fallback_result <- processx::run(
          command = get_npm_command(),
          args = c("run", platform_script),
          wd = output_dir,
          echo = FALSE,
          spinner = verbose,
          error_on_status = FALSE
        )

        # Report key build stages from electron-builder output
        if (verbose && nzchar(fallback_result$stderr)) {
          lines <- strsplit(fallback_result$stderr, "\n")[[1]]
          for (line in lines) {
            line <- trimws(line)
            if (grepl("^\\s*\u2022\\s*packaging", line)) {
              cli::cli_alert_info("Packaging application...")
            } else if (grepl("^\\s*\u2022\\s*building\\s+target", line)) {
              cli::cli_alert_info("Creating installer...")
            } else if (grepl("^\\s*\u2022\\s*signing", line) && !grepl("signtool", line)) {
              cli::cli_alert_info("Signing application...")
            }
          }
        }

        if (fallback_result$status == 0) {
          cli::cli_alert_success("Built for {p} (fallback - may include multiple architectures)")
        } else {
          cli::cli_alert_warning("Fallback build also failed for {p}: {fallback_result$stderr}")
        }
      } else {
        cli::cli_alert_warning("No build script found for platform {p}")
      }
    }
  }
}
