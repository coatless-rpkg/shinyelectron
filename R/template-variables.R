#' Build the Whisker template variable list for the shared shell
#'
#' Constructs the named list passed to `whisker::whisker.render()` when
#' assembling the Electron app. Kept separate from `process_templates()`
#' so the variable construction is testable independently.
#'
#' Every variable here corresponds to a `{{...}}` placeholder in
#' `inst/electron/shared/main.js`, `lifecycle.html`, `preload.js`, or
#' `launcher.html`. Adding a new placeholder requires adding it here.
#'
#' @param app_name Character. Display name of the app.
#' @param app_slug Character. Path-safe slug derived from app_name.
#' @param app_type Character. One of ALL_APP_TYPES.
#' @param runtime_strategy Character. Resolved runtime strategy.
#' @param icon Character path to icon file, or NULL.
#' @param backend_module Character. Resolved backend filename
#'   (e.g., "native-r.js").
#' @param brand List or NULL. Parsed `_brand.yml` contents if present.
#' @param config List. Effective merged configuration.
#' @param is_multi_app Logical.
#' @param apps_manifest List or NULL. Multi-app manifest entries.
#' @return Named list suitable for Whisker rendering.
#' @keywords internal
generate_template_variables <- function(app_name, app_slug, app_type,
                                        runtime_strategy, icon,
                                        backend_module, brand, config,
                                        is_multi_app = FALSE,
                                        apps_manifest = NULL) {
  backend_config <- list(
    runtime_strategy = runtime_strategy,
    app_type = app_type,
    app_slug = app_slug,
    port_retry_count = config$lifecycle$port_retry_count %||%
      SHINYELECTRON_DEFAULTS$lifecycle$port_retry_count
  )

  list(
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

    # Lifecycle
    shutdown_timeout = config$lifecycle$shutdown_timeout %||%
      SHINYELECTRON_DEFAULTS$lifecycle$shutdown_timeout,
    port_retry_count = config$lifecycle$port_retry_count %||%
      SHINYELECTRON_DEFAULTS$lifecycle$port_retry_count,

    # System tray
    tray_enabled = config$tray$enabled %||% SHINYELECTRON_DEFAULTS$tray$enabled,
    minimize_to_tray = config$tray$minimize_to_tray %||% SHINYELECTRON_DEFAULTS$tray$minimize_to_tray,
    close_to_tray = config$tray$close_to_tray %||% SHINYELECTRON_DEFAULTS$tray$close_to_tray,
    tray_tooltip = config$tray$tooltip %||% app_name,
    tray_icon = config$tray$icon,

    # Menus
    menu_enabled = config$menu$enabled %||% SHINYELECTRON_DEFAULTS$menu$enabled,
    menu_template = config$menu$template %||% SHINYELECTRON_DEFAULTS$menu$template,
    menu_minimal = identical(config$menu$template %||% "default", "minimal"),
    show_dev_tools = config$menu$show_dev_tools %||% SHINYELECTRON_DEFAULTS$menu$show_dev_tools,
    help_url = config$menu$help_url %||% "",

    # Auto-updates
    updates_enabled = config$updates$enabled %||% SHINYELECTRON_DEFAULTS$updates$enabled,
    update_provider = config$updates$provider %||% SHINYELECTRON_DEFAULTS$updates$provider,
    check_on_startup = config$updates$check_on_startup %||% SHINYELECTRON_DEFAULTS$updates$check_on_startup,
    auto_download = config$updates$auto_download %||% SHINYELECTRON_DEFAULTS$updates$auto_download,
    auto_install = config$updates$auto_install %||% SHINYELECTRON_DEFAULTS$updates$auto_install,
    update_owner = config$updates$github$owner %||% "",
    update_repo = config$updates$github$repo %||% "",

    # Splash screen
    splash_background = config$splash$background %||% SHINYELECTRON_DEFAULTS$splash$background,
    splash_text = config$splash$text %||% SHINYELECTRON_DEFAULTS$splash$text,
    splash_text_color = config$splash$text_color %||% SHINYELECTRON_DEFAULTS$splash$text_color,
    has_splash_image = !is.null(config$splash$image),
    splash_image = if (!is.null(config$splash$image)) "assets/splash-image.png" else "",

    # Preloader
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

    # Multi-app
    is_multi_app = is_multi_app,
    apps_json = if (is_multi_app) jsonlite::toJSON(apps_manifest, auto_unbox = TRUE) else "[]"
  )
}
