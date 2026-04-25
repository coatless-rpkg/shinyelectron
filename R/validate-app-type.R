#' Validate application type
#'
#' @param app_type Character application type
#' @keywords internal
validate_app_type <- function(app_type) {
  valid_types <- SHINYELECTRON_DEFAULTS$valid_app_types
  if (!app_type %in% valid_types) {
    cli::cli_abort(c(
      "Invalid app_type: {.val {app_type}}",
      "i" = "Must be one of: {.val {valid_types}}",
      "i" = "See {.url https://r-pkg.thecoatlessprofessor.com/shinyelectron/articles/configuration.html}"
    ))
  }
}

#' Validate runtime strategy
#'
#' @param strategy Character string. The runtime strategy to validate.
#' @keywords internal
validate_runtime_strategy <- function(strategy) {
  valid <- SHINYELECTRON_DEFAULTS$valid_runtime_strategies
  if (!strategy %in% valid) {
    cli::cli_abort(c(
      "Invalid runtime strategy: {.val {strategy}}",
      "i" = "Valid strategies: {.val {valid}}"
    ))
  }
  invisible(TRUE)
}

#' Infer the default runtime strategy
#'
#' Returns the passed strategy, or falls back to the package default
#' (`"shinylive"`) when unset. The `app_type` argument is accepted for
#' backwards compatibility and ignored.
#'
#' @param strategy Character string or NULL. Explicit strategy, or NULL.
#' @param app_type Ignored. Retained for signature compatibility.
#' @return Character string. Either the explicit strategy or `"shinylive"`.
#' @keywords internal
infer_runtime_strategy <- function(strategy, app_type = NULL) {
  strategy %||% "shinylive"
}

#' Normalize app_type and runtime_strategy arguments
#'
#' Translates legacy app_type values (`r-shinylive`, `py-shinylive`) to the
#' canonical language pair (`r-shiny`, `py-shiny`) and backfills
#' `runtime_strategy = "shinylive"` when the caller has not set it. Emits
#' a deprecation warning of class `"shinyelectron_deprecated_app_type"`
#' so callers can muffle it and tests can match it precisely. Errors when
#' a legacy type is combined with an explicit non-shinylive strategy,
#' since that combination never worked under the old API.
#'
#' @param app_type Character string or NULL. Raw app_type from the user.
#' @param runtime_strategy Character string or NULL. Raw runtime_strategy.
#' @return List with elements `app_type` (canonical or NULL),
#'   `runtime_strategy` (may still be NULL), and `deprecated` (logical).
#' @keywords internal
normalize_app_type_arg <- function(app_type, runtime_strategy = NULL) {
  legacy_map <- c(
    "r-shinylive"  = "r-shiny",
    "py-shinylive" = "py-shiny"
  )

  if (is.null(app_type) || !nzchar(app_type)) {
    return(list(app_type = NULL, runtime_strategy = runtime_strategy, deprecated = FALSE))
  }

  if (app_type %in% names(legacy_map)) {
    new_type <- unname(legacy_map[app_type])

    if (!is.null(runtime_strategy) && runtime_strategy != "shinylive") {
      cli::cli_abort(c(
        "Conflicting arguments",
        "x" = "Legacy {.val {app_type}} implies {.arg runtime_strategy = \"shinylive\"}, but you passed {.val {runtime_strategy}}",
        "i" = "Use {.code app_type = \"{new_type}\", runtime_strategy = \"{runtime_strategy}\"} instead"
      ))
    }

    cli::cli_warn(c(
      "The {.val {app_type}} app type is deprecated",
      "i" = "Use {.code app_type = \"{new_type}\", runtime_strategy = \"shinylive\"} instead",
      "i" = "Shinylive is now a runtime strategy, not an app type"
    ), class = "shinyelectron_deprecated_app_type")

    return(list(
      app_type = new_type,
      runtime_strategy = runtime_strategy %||% "shinylive",
      deprecated = TRUE
    ))
  }

  list(app_type = app_type, runtime_strategy = runtime_strategy, deprecated = FALSE)
}

#' Check if config is multi-app mode
#'
#' @param config List. Configuration.
#' @return Logical.
#' @keywords internal
is_multi_app <- function(config) {
  !is.null(config$apps) && is.list(config$apps) && length(config$apps) >= 2
}

#' Resolve the app type for a multi-app entry
#'
#' Reads per-app `type`, falls back to suite-level `build.type`, and
#' routes legacy values through [normalize_app_type_arg()] so the
#' caller always sees canonical `"r-shiny"` / `"py-shiny"`. A legacy
#' per-app type is treated as a self-contained shinylive declaration
#' and does not mix with the suite-level `runtime_strategy`, since
#' the two could otherwise conflict (e.g. a legacy `"r-shinylive"`
#' entry inside a suite whose default strategy is `"system"`).
#'
#' @param app List. Single app entry from config$apps.
#' @param config List. Full configuration.
#' @return Character string. The resolved canonical app type.
#' @keywords internal
resolve_app_type <- function(app, config) {
  raw <- app$type %||% config$build$type %||% "r-shiny"
  if (raw %in% c("r-shinylive", "py-shinylive")) {
    normalized <- normalize_app_type_arg(raw)
    return(normalized$app_type)
  }
  raw_strategy <- app$runtime_strategy %||% config$build$runtime_strategy
  normalized <- normalize_app_type_arg(raw, raw_strategy)
  normalized$app_type %||% "r-shiny"
}

#' Resolve the runtime strategy for a multi-app entry
#'
#' Order of precedence: explicit per-app `runtime_strategy`, then
#' legacy per-app type (forces `"shinylive"`), then suite-level
#' `build.runtime_strategy`, then the package default `"shinylive"`.
#'
#' @param app List. Single app entry from config$apps.
#' @param config List. Full configuration.
#' @return Character string. The resolved runtime strategy.
#' @keywords internal
resolve_app_strategy <- function(app, config) {
  if (!is.null(app$runtime_strategy)) return(app$runtime_strategy)
  raw_type <- app$type %||% config$build$type
  if (!is.null(raw_type) && raw_type %in% c("r-shinylive", "py-shinylive")) {
    return("shinylive")
  }
  config$build$runtime_strategy %||% "shinylive"
}

#' Validate multi-app configuration
#'
#' @param config List. Configuration with apps array.
#' @param basedir Character. Base directory for resolving relative paths.
#' @keywords internal
validate_multi_app_config <- function(config, basedir) {
  apps <- config$apps

  # Check for required fields
  example_hint <- "Example: {.code apps: [{ id: 'dashboard', name: 'Dashboard', path: './src/dashboard' }]}"
  for (i in seq_along(apps)) {
    app <- apps[[i]]
    if (is.null(app$id) || !nzchar(app$id)) {
      cli::cli_abort(c(
        "Multi-app config entry {i} is missing required {.field id}",
        "i" = "Each app must have: {.field id}, {.field name}, {.field path}",
        "i" = example_hint
      ))
    }
    if (is.null(app$name) || !nzchar(app$name)) {
      cli::cli_abort(c(
        "Multi-app config entry {i} ({.val {app$id}}) is missing required {.field name}",
        "i" = example_hint
      ))
    }
    if (is.null(app$path) || !nzchar(app$path)) {
      cli::cli_abort(c(
        "Multi-app config entry {i} ({.val {app$id}}) is missing required {.field path}",
        "i" = example_hint
      ))
    }
  }

  # Check for duplicate ids
  ids <- vapply(apps, function(a) a$id, character(1))
  dupes <- ids[duplicated(ids)]
  if (length(dupes) > 0) {
    cli::cli_abort("Duplicate app id{?s}: {.val {dupes}}")
  }

  # Validate each app directory and structure
  for (app in apps) {
    app_path <- fs::path(basedir, app$path)
    if (!fs::dir_exists(app_path)) {
      cli::cli_abort("App {.val {app$id}} directory does not exist: {.path {app_path}}")
    }

    app_type <- resolve_app_type(app, config)
    if (grepl("^r-", app_type)) {
      validate_shiny_app_structure(app_path)
    } else if (grepl("^py-", app_type)) {
      validate_python_app_structure(app_path)
    }
  }

  invisible(TRUE)
}
