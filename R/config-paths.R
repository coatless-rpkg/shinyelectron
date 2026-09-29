# Keys in _shinyelectron.yml whose values name files on the build machine,
# given as their location in the merged configuration. resolve_config_paths()
# also resolves the `path` and `icon` of each multi-app `apps` entry. Paths
# that the packaged app uses on the end user's machine (`app.log_dir`,
# `dependencies.r.lib_path` and the host side of `container.volumes`) are
# deliberately left out: they must not point into the build machine.
CONFIG_PATH_KEYS <- list(
  "icon",
  c("icons", "mac"),
  c("icons", "win"),
  c("icons", "linux"),
  c("splash", "image"),
  c("tray", "icon"),
  c("signing", "win", "certificate_file")
)

#' Resolve a path written in the configuration file
#'
#' Paths in `_shinyelectron.yml` are relative to the directory that holds the
#' file: the app directory, or the suite root of a multi-app suite. `~` is
#' expanded, and an absolute path is kept as it is.
#'
#' @param path Character. A path as written in the configuration.
#' @param base_dir Character. The directory that holds `_shinyelectron.yml`.
#' @return Character. The absolute path.
#' @keywords internal
resolve_config_path <- function(path, base_dir) {
  base_dir <- fs::path_abs(path.expand(base_dir))
  as.character(fs::path_abs(path.expand(as.character(path)), start = base_dir))
}

#' Resolve the file paths in a configuration
#'
#' Makes every configuration value that names a file on the build machine
#' absolute with [resolve_config_path()]: `icon`, `icons.mac`, `icons.win`,
#' `icons.linux`, `splash.image`, `tray.icon`,
#' `signing.win.certificate_file`, and the `path` and `icon` of each `apps`
#' entry. [export()] calls this right after reading `_shinyelectron.yml`, so
#' the paths no longer depend on the working directory. An empty string
#' counts as unset and is removed. Other values that are not a single string
#' are left for the later checks to report.
#'
#' @param config List. The merged configuration.
#' @param base_dir Character. The directory that holds `_shinyelectron.yml`.
#' @return `config`, with those paths made absolute.
#' @keywords internal
resolve_config_paths <- function(config, base_dir) {
  resolve <- function(value) {
    if (!is.character(value) || length(value) != 1L || is.na(value)) {
      return(value)
    }
    if (!nzchar(value)) {
      return(NULL)
    }
    resolve_config_path(value, base_dir)
  }

  for (key in CONFIG_PATH_KEYS) {
    value <- config_value(config, key)
    if (!is.null(value)) {
      config[[key]] <- resolve(value)
    }
  }

  apps <- config_value(config, "apps")
  if (is.list(apps)) {
    for (i in seq_along(apps)) {
      if (!is.list(apps[[i]])) next
      for (field in c("path", "icon")) {
        if (!is.null(apps[[i]][[field]])) {
          apps[[i]][[field]] <- resolve(apps[[i]][[field]])
        }
      }
    }
    config[["apps"]] <- apps
  }

  config
}

#' Get a nested configuration value
#'
#' @param config List. The configuration.
#' @param key Character vector. The names leading to the value, such as
#'   `c("splash", "image")`.
#' @return The value, or `NULL` when any level is missing.
#' @keywords internal
config_value <- function(config, key) {
  for (name in key) {
    if (!is.list(config) || !name %in% names(config)) {
      return(NULL)
    }
    config <- config[[name]]
  }
  config
}

#' Check that a configured path names an existing file
#'
#' @param path A configuration value.
#' @return `TRUE` when `path` is a single string naming an existing file (a
#'   directory does not count), otherwise `FALSE`.
#' @keywords internal
config_file_exists <- function(path) {
  is.character(path) && length(path) == 1L && !is.na(path) && nzchar(path) &&
    isTRUE(unname(fs::is_file(path.expand(path))))
}

#' Report a configured file that does not exist
#'
#' Names the key and the absolute path that was checked, and says what
#' happens next.
#'
#' @param field Character. The key, such as `"splash.image"`.
#' @param path The configured value.
#' @param consequence Character. What the build does without the file.
#' @param base_dir Character or `NULL`. The directory relative paths in
#'   `_shinyelectron.yml` were resolved against. `NULL` for a configuration
#'   passed straight to [build_electron_app()], whose relative paths are
#'   taken from the working directory.
#' @param app_id Character or `NULL`. The suite app the key belongs to.
#' @param error Logical. Whether to stop instead of warning.
#' @param call Environment. The function the error is reported from.
#' @keywords internal
signal_missing_config_file <- function(field, path, consequence = NULL,
                                       base_dir = NULL, app_id = NULL,
                                       error = FALSE, call = parent.frame()) {
  shown <- if (is.character(path) && length(path) == 1L && !is.na(path) &&
               nzchar(path)) {
    fs::path_abs(path.expand(path))
  } else {
    paste(format(path), collapse = " ")
  }

  msg <- if (is.null(app_id)) {
    "{.field {field}} file not found: {.path {shown}}"
  } else {
    "{.field {field}} file of app {.val {app_id}} not found: {.path {shown}}"
  }
  if (!is.null(base_dir)) {
    base_dir <- fs::path_abs(path.expand(base_dir))
    msg <- c(msg, "i" = "Relative paths in {.file {CONFIG_FILENAME}} are resolved against {.path {base_dir}}.")
  }
  if (!is.null(consequence)) {
    msg <- c(msg, "i" = consequence)
  }

  if (error) {
    cli::cli_abort(msg, class = "shinyelectron_config_file_not_found",
                   call = call)
  }
  cli::cli_warn(msg, class = "shinyelectron_config_file_not_found")
}

#' Pick the app icon named in the configuration
#'
#' The top-level `icon` wins over the per-platform `icons` entry, as in
#' [export()].
#'
#' @param config List. The configuration.
#' @param platform Character. The target platform: `"mac"`, `"win"` or
#'   `"linux"`.
#' @return `NULL` when no icon is configured; otherwise a list with `field`
#'   (the key, such as `"icons.mac"`) and `path`.
#' @keywords internal
config_icon <- function(config, platform) {
  for (key in list("icon", c("icons", platform))) {
    path <- config_value(config, key)
    if (!is.null(path)) {
      return(list(field = paste(key, collapse = "."), path = path))
    }
  }
  NULL
}

#' Check the app icon named in the configuration
#'
#' A configured icon that does not exist stops the export, as a missing
#' `icon` argument does in [validate_icon()]: a build that quietly fell back
#' to the default Electron icon would be easy to ship by mistake.
#'
#' @inheritParams config_icon
#' @param base_dir Character. The directory relative paths in
#'   `_shinyelectron.yml` were resolved against, named in the error.
#' @param call Environment. The function the error is reported from.
#' @return The icon path, or `NULL` when no icon is configured.
#' @keywords internal
check_config_icon <- function(config, platform, base_dir,
                              call = parent.frame()) {
  icon <- config_icon(config, platform)
  if (is.null(icon)) {
    return(NULL)
  }
  if (!config_file_exists(icon$path)) {
    signal_missing_config_file(icon$field, icon$path, base_dir = base_dir,
                               error = TRUE, call = call)
  }
  icon$path
}

#' Warn when the configured Windows signing certificate does not exist
#'
#' [export()] calls this when it signs a Windows build, whether signing was
#' turned on by the `sign` argument or by `signing.sign`. The key is kept, so
#' electron-builder still fails on it rather than quietly building an
#' unsigned installer.
#'
#' @param config List. The configuration, with paths already resolved.
#' @param base_dir Character or `NULL`. The directory relative paths in
#'   `_shinyelectron.yml` were resolved against, named in the warning.
#' @return `TRUE` when the certificate is unset or exists, otherwise `FALSE`
#'   (invisibly).
#' @keywords internal
check_config_certificate <- function(config, base_dir = NULL) {
  cert <- config_value(config, c("signing", "win", "certificate_file"))
  if (is.null(cert) || config_file_exists(cert)) {
    return(invisible(TRUE))
  }
  signal_missing_config_file("signing.win.certificate_file", cert,
                             consequence = "Signing the Windows build will fail.",
                             base_dir = base_dir)
  invisible(FALSE)
}

#' Find the optional configured files that do not exist
#'
#' The splash image, the tray icon and the launcher icon of each suite app
#' are optional: without them the build uses a default.
#'
#' @param config List. The configuration.
#' @return A list with one element per missing file. Each is a list with
#'   `field` (the key), `path`, `consequence` (what the build uses instead),
#'   and either `key` (the location in `config`) or `app` (the index in
#'   `config$apps`) and `id`.
#' @keywords internal
missing_config_files <- function(config) {
  optional <- list(
    list(key = c("splash", "image"),
         consequence = "The splash screen shows the app's initial instead."),
    list(key = c("tray", "icon"),
         consequence = "The tray uses the app icon instead.")
  )

  missing <- list()
  for (entry in optional) {
    path <- config_value(config, entry$key)
    if (!is.null(path) && !config_file_exists(path)) {
      missing[[length(missing) + 1L]] <- list(
        field = paste(entry$key, collapse = "."),
        key = entry$key,
        path = path,
        consequence = entry$consequence
      )
    }
  }

  apps <- config_value(config, "apps")
  if (is.list(apps)) {
    for (i in seq_along(apps)) {
      path <- if (is.list(apps[[i]])) apps[[i]][["icon"]]
      if (!is.null(path) && !config_file_exists(path)) {
        missing[[length(missing) + 1L]] <- list(
          field = "icon",
          app = i,
          id = paste(format(apps[[i]][["id"]] %||% i), collapse = " "),
          path = path,
          consequence = "The launcher card shows the app's initial instead."
        )
      }
    }
  }

  missing
}

#' Warn about and drop the optional configured files that do not exist
#'
#' Dropping the key makes the build use its default instead of referring to
#' a file that is never copied. [export()] calls this once the paths are
#' resolved, and [process_templates()] calls it again for a configuration
#' passed straight to [build_electron_app()].
#'
#' @param config List. The configuration.
#' @param base_dir Character or `NULL`. The directory relative paths in
#'   `_shinyelectron.yml` were resolved against, named in the warning.
#' @return `config`, without the missing files.
#' @keywords internal
drop_missing_config_files <- function(config, base_dir = NULL) {
  for (entry in missing_config_files(config)) {
    signal_missing_config_file(entry$field, entry$path,
                               consequence = entry$consequence,
                               base_dir = base_dir, app_id = entry$id)
    if (is.null(entry$app)) {
      config[[entry$key]] <- NULL
    } else {
      config[["apps"]][[entry$app]][["icon"]] <- NULL
    }
  }
  config
}

#' Build path of a suite app's launcher icon
#'
#' [copy_brand_assets()] copies each app's `icon` here, and the apps manifest
#' points the launcher at it.
#'
#' @param app List. One `apps` entry, with its `icon` already resolved.
#' @return `"assets/apps/<id>.<ext>"`, relative to the Electron project, or
#'   `NULL` when the app has no icon.
#' @keywords internal
app_icon_asset <- function(app) {
  icon <- app[["icon"]]
  if (!is.character(icon) || length(icon) != 1L || is.na(icon) ||
      !nzchar(icon)) {
    return(NULL)
  }
  ext <- tools::file_ext(icon)
  paste0("assets/apps/", app[["id"]], if (nzchar(ext)) paste0(".", ext))
}
