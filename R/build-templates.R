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
