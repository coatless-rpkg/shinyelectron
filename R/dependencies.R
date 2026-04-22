#' Generate a dependency manifest file
#'
#' Creates a JSON manifest describing the packages an app needs.
#' This manifest is written into the Electron app and used by the
#' auto-download and container strategies to install packages at runtime.
#'
#' @param packages Character vector of package names.
#' @param language Character string: "r" or "python".
#' @param repos List of R repository URLs (for language = "r").
#' @param index_urls List of Python index URLs (for language = "python").
#' @return Character string of JSON content.
#' @keywords internal
generate_dependency_manifest <- function(packages, language,
                                         repos = NULL, index_urls = NULL) {
  manifest <- list(
    schema_version = MANIFEST_SCHEMA_VERSION,
    language = language,
    packages = as.list(packages),
    binary_only = TRUE
  )

  if (language == "r") {
    manifest$repos <- repos %||% SHINYELECTRON_DEFAULTS$dependencies$r$repos
  } else if (language == "python") {
    manifest$index_urls <- index_urls %||%
      SHINYELECTRON_DEFAULTS$dependencies$python$index_urls
  }

  # Look up Linux system dependencies at build time (optional, requires pak)
  if (language == "r" && length(packages) > 0) {
    if (requireNamespace("pak", quietly = TRUE)) {
      tryCatch({
        sysreqs <- pak::pkg_sysreqs(packages)
        if (!is.null(sysreqs) && !is.null(sysreqs$packages)) {
          manifest$system_deps <- list(
            debian = unique(unlist(sysreqs$packages[grepl("debian|ubuntu", names(sysreqs$packages), ignore.case = TRUE)])),
            fedora = unique(unlist(sysreqs$packages[grepl("fedora|rhel|centos", names(sysreqs$packages), ignore.case = TRUE)]))
          )
        }
      }, error = function(e) {
        # pak sysreqs lookup failed -- skip silently
      })
    }
  }

  jsonlite::toJSON(manifest, pretty = TRUE, auto_unbox = TRUE)
}

#' Resolve application dependencies
#'
#' Top-level function that detects, merges, and returns the final list of
#' package dependencies for an app. Called from export() for native app types.
#'
#' @param appdir Character string. Path to the app directory.
#' @param app_type Character string. The app type.
#' @param config List. The effective configuration.
#' @return List with `packages`, `language`, and `repos`/`index_urls`,
#'   or NULL for shinylive types (which don't need dependency management).
#' @keywords internal
resolve_app_dependencies <- function(appdir, app_type, config) {
  if (app_type %in% SHINYLIVE_TYPES) {
    return(NULL)
  }

  config_deps <- config$dependencies %||% SHINYELECTRON_DEFAULTS$dependencies

  if (grepl("^r-", app_type)) {
    detected <- detect_r_dependencies(appdir)
    merged <- merge_r_dependencies(detected, config_deps)
    list(
      language = "r",
      packages = merged$packages,
      repos = merged$repos
    )
  } else {
    detected <- detect_py_dependencies(appdir)
    merged <- merge_py_dependencies(detected, config_deps)
    list(
      language = "python",
      packages = merged$packages,
      index_urls = merged$index_urls
    )
  }
}
