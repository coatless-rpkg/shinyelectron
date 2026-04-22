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

#' Validate runtime strategy is compatible with app type
#'
#' @param strategy Character string. The runtime strategy.
#' @param app_type Character string. The app type.
#' @keywords internal
validate_runtime_strategy_for_app_type <- function(strategy, app_type) {
  if (app_type %in% SHINYLIVE_TYPES && strategy != "shinylive") {
    cli::cli_abort(c(
      "Runtime strategy {.val {strategy}} is not applicable to app type {.val {app_type}}",
      "i" = "Shinylive app types run entirely in the browser and do not need a runtime strategy"
    ))
  }
  invisible(TRUE)
}

#' Infer the default runtime strategy for an app type
#'
#' @param strategy Character string or NULL. Explicit strategy, or NULL to infer.
#' @param app_type Character string. The app type.
#' @return Character string. The resolved runtime strategy.
#' @keywords internal
infer_runtime_strategy <- function(strategy, app_type) {
  if (!is.null(strategy)) {
    return(strategy)
  }
  if (app_type %in% SHINYLIVE_TYPES) {
    "shinylive"
  } else {
    "auto-download"
  }
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
#' @param app List. Single app entry from config$apps.
#' @param config List. Full configuration.
#' @return Character string. The resolved app type.
#' @keywords internal
resolve_app_type <- function(app, config) {
  app$type %||% config$build$type %||% "r-shinylive"
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
