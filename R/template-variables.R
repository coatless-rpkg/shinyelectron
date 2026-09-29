#' Build the Whisker template variable list for the shared shell
#'
#' Constructs the named list passed to `whisker::whisker.render()` when
#' assembling the Electron app. Kept separate from `process_templates()`
#' so the variable construction is testable independently.
#'
#' Most variables here correspond to a `{{...}}` placeholder in
#' `inst/electron/shared/main.js`, `lifecycle.html`, or `launcher.html`.
#' The list is a superset: some entries are serialized into
#' `backend_config_json` (and consumed by the backend modules rather than a
#' template) or are reserved for future placeholders. Adding a new
#' placeholder requires adding it here.
#'
#' A configuration string that `main.js` places inside a single-quoted
#' JavaScript literal also has an escaped `*_js` entry (see [js_str()]),
#' which the template renders with a triple mustache, as in
#' `'{{{app_name_js}}}'`. The plain entries are HTML-escaped by a double
#' mustache and belong in the HTML templates.
#'
#' @param app_name Character. Display name of the app.
#' @param app_slug Character. Path-safe slug derived from app_name.
#' @param app_type Character. `"r-shiny"` or `"py-shiny"`.
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
    prompt_before_install = config$lifecycle$prompt_before_install %||%
      SHINYELECTRON_DEFAULTS$lifecycle$prompt_before_install,
    prompt_runtime_version = config$lifecycle$prompt_runtime_version %||%
      SHINYELECTRON_DEFAULTS$lifecycle$prompt_runtime_version
  )

  # The container backend reads its image/engine/volume settings from the
  # inlined backend config (see inst/electron/backends/container.js); fold
  # them in here so `_shinyelectron.yml` container settings reach runtime.
  if (identical(runtime_strategy, "container")) {
    backend_config <- c(backend_config, generate_container_config(config, app_type = app_type))
  }

  # Drop NULL entries: jsonlite serializes a NULL element as an empty object
  # ({}), which the JS side would read as a truthy value (e.g. an unset
  # container_image becoming {} instead of being absent).
  backend_config <- Filter(Negate(is.null), backend_config)

  # Config strings that main.js places inside single-quoted JavaScript
  # literals. Each one also gets a js_str()-escaped `*_js` entry below.
  app_version <- config$app$version %||% SHINYELECTRON_DEFAULTS$app_version
  tray_tooltip <- config$tray$tooltip %||% app_name
  # copy_brand_assets() writes the tray icon to assets/<basename>, and
  # main.js joins it under assets/, so the template must carry only the
  # basename (mirrors the splash image handling below).
  tray_icon <- if (!is.null(config$tray$icon)) basename(config$tray$icon) else NULL
  help_url <- config$menu$help_url %||% ""
  log_level <- config$app$log_level %||% SHINYELECTRON_DEFAULTS$logging$log_level
  log_dir <- config$app$log_dir %||% ""

  list(
    app_name = app_name,
    app_name_js = js_str(app_name),
    app_slug = app_slug,
    app_type = app_type,
    app_version = app_version,
    app_version_js = js_str(app_version),
    has_icon = !is.null(icon),
    # copy_brand_assets() preserves the icon's extension (icon.ico/.icns/.png);
    # carry the real filename so the BrowserWindow icon path is not broken.
    icon_file = if (!is.null(icon)) paste0("icon.", tools::file_ext(icon)) else "icon.png",
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

    # System tray
    tray_enabled = config$tray$enabled %||% SHINYELECTRON_DEFAULTS$tray$enabled,
    minimize_to_tray = config$tray$minimize_to_tray %||% SHINYELECTRON_DEFAULTS$tray$minimize_to_tray,
    close_to_tray = config$tray$close_to_tray %||% SHINYELECTRON_DEFAULTS$tray$close_to_tray,
    tray_tooltip = tray_tooltip,
    tray_tooltip_js = js_str(tray_tooltip),
    tray_icon = tray_icon,
    tray_icon_js = js_str(tray_icon),

    # Menus
    menu_enabled = config$menu$enabled %||% SHINYELECTRON_DEFAULTS$menu$enabled,
    menu_template = config$menu$template %||% SHINYELECTRON_DEFAULTS$menu$template,
    menu_minimal = identical(config$menu$template %||% "default", "minimal"),
    show_dev_tools = config$menu$show_dev_tools %||% SHINYELECTRON_DEFAULTS$menu$show_dev_tools,
    help_url = help_url,
    help_url_js = js_str(help_url),
    # whisker renders a section for "", so gate Help > Documentation on a
    # real URL rather than on the value itself.
    has_help_url = is_nonempty_string(config$menu$help_url),

    # Auto-updates
    updates_enabled = config$updates$enabled %||% SHINYELECTRON_DEFAULTS$updates$enabled,
    update_provider = config$updates$provider %||% SHINYELECTRON_DEFAULTS$updates$provider,
    check_on_startup = config$updates$check_on_startup %||% SHINYELECTRON_DEFAULTS$updates$check_on_startup,
    auto_download = config$updates$auto_download %||% SHINYELECTRON_DEFAULTS$updates$auto_download,
    auto_install = config$updates$auto_install %||% SHINYELECTRON_DEFAULTS$updates$auto_install,
    update_owner = config$updates$github$owner %||% "",
    update_repo = config$updates$github$repo %||% "",

    # Splash screen
    splash_enabled = config$splash$enabled %||% SHINYELECTRON_DEFAULTS$splash$enabled,
    splash_duration = config$splash$duration %||% SHINYELECTRON_DEFAULTS$splash$duration,
    splash_background = config$splash$background %||% (brand$color$background %||% "#f8fafc"),
    splash_text = config$splash$text %||% SHINYELECTRON_DEFAULTS$splash$text,
    splash_text_color = config$splash$text_color %||% SHINYELECTRON_DEFAULTS$splash$text_color,
    has_splash_image = !is.null(config$splash$image),
    splash_image = if (!is.null(config$splash$image)) "assets/splash-image.png" else "",

    # Preloader
    preloader_style = config$preloader$style %||% SHINYELECTRON_DEFAULTS$preloader$style,
    preloader_style_spinner = identical(config$preloader$style %||% "spinner", "spinner"),
    preloader_style_bar = identical(config$preloader$style %||% "spinner", "bar"),
    preloader_style_dots = identical(config$preloader$style %||% "spinner", "dots"),
    preloader_message = config$preloader$message %||% SHINYELECTRON_DEFAULTS$preloader$message,
    preloader_background = config$preloader$background %||% (brand$color$background %||% "#f8fafc"),

    # Custom lifecycle HTML
    has_custom_splash = !is.null(config$lifecycle$custom_splash_html),
    custom_splash_html = config$lifecycle$custom_splash_html %||% "",
    has_custom_error = !is.null(config$lifecycle$custom_error_html),
    custom_error_html = config$lifecycle$custom_error_html %||% "",

    # Logging
    log_level = log_level,
    log_level_js = js_str(log_level),
    has_log_dir = !is.null(config$app$log_dir),
    log_dir = log_dir,
    log_dir_js = js_str(log_dir),

    # Multi-app
    is_multi_app = is_multi_app,
    apps_json = if (is_multi_app) jsonlite::toJSON(apps_manifest, auto_unbox = TRUE) else "[]"
  )
}

#' Escape a value for a single-quoted JavaScript string literal
#'
#' Rendered JavaScript templates such as `main.js` place configuration
#' strings between single quotes, as in `title: 'Close {{{app_name_js}}}'`.
#' This escapes backslashes and then single quotes, turns carriage returns
#' and line feeds into spaces, and writes U+2028 and U+2029 as escape
#' sequences, so no value can end the literal early or change its meaning
#' (a Windows path keeps its backslashes). Double quotes are left alone, so
#' use the result only inside single quotes.
#'
#' Render the result with a triple mustache (`{{{name_js}}}`). A double
#' mustache would HTML-escape it again and turn `&` into `&amp;`. HTML
#' templates such as `lifecycle.html` keep the double mustache.
#'
#' @param x A character vector, a non-character scalar (coerced with
#'   [as.character()], such as a version that YAML read as a number), or
#'   `NULL`.
#' @return A character vector, or `NULL` when `x` is `NULL`.
#' @keywords internal
js_str <- function(x) {
  if (is.null(x)) return(NULL)
  if (!is.character(x) && length(x) == 1L) x <- as.character(x)
  x <- gsub("\\", "\\\\", x, fixed = TRUE)
  x <- gsub("'", "\\'", x, fixed = TRUE)
  x <- gsub("\r", " ", x, fixed = TRUE)
  x <- gsub("\n", " ", x, fixed = TRUE)
  x <- gsub("\u2028", "\\u2028", x, fixed = TRUE)
  x <- gsub("\u2029", "\\u2029", x, fixed = TRUE)
  x
}

#' Test for a single non-empty string
#'
#' Template flags use this so an optional setting renders only when it holds
#' real text: `NULL`, `""`, `NA`, and non-character values all count as unset.
#'
#' @param x Value to test.
#' @return `TRUE` or `FALSE`.
#' @keywords internal
is_nonempty_string <- function(x) {
  is.character(x) && length(x) == 1L && !is.na(x) && nzchar(x)
}
