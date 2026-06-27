#' Query Linux system package names for a set of R packages
#'
#' Resolves the distribution system packages required by `pkgs` and their
#' recursive dependencies using the Posit Package Manager system-requirements
#' service. Returns `character(0)` on any failure so callers degrade gracefully
#' (a user can still name packages via `dependencies.system_packages`).
#'
#' Queried over HTTP directly rather than through `pak::pkg_sysreqs()`, whose
#' resolver returns an empty mapping in common configurations even when the
#' underlying data is available.
#'
#' @param pkgs Character vector of R package names.
#' @param distribution Linux distribution, e.g. `"ubuntu"` or `"redhat"`.
#' @param release Distribution release, e.g. `"24.04"` or `"9"`.
#' @return Character vector of system package names (sorted, de-duplicated).
#' @keywords internal
query_sysreqs <- function(pkgs, distribution = "ubuntu", release = "24.04") {
  pkgs <- unique(pkgs[nzchar(pkgs)])
  if (length(pkgs) == 0) return(character(0))

  url <- paste0(
    "https://packagemanager.posit.co/__api__/repos/cran/sysreqs",
    "?all=false&distribution=", distribution, "&release=", release,
    paste0("&pkgname=", utils::URLencode(pkgs, reserved = TRUE), collapse = "")
  )

  tmp <- tempfile(fileext = ".json")
  on.exit(unlink(tmp), add = TRUE)
  ok <- tryCatch(
    identical(utils::download.file(url, tmp, quiet = TRUE, mode = "wb"), 0L),
    error = function(e) FALSE
  )
  if (!ok) return(character(0))

  parsed <- tryCatch(
    jsonlite::fromJSON(tmp, simplifyVector = FALSE),
    error = function(e) NULL
  )
  reqs <- parsed$requirements
  if (is.null(reqs)) return(character(0))

  sys <- unlist(lapply(reqs, function(r) r$requirements$packages))
  sort(unique(sys[nzchar(sys)]))
}

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

  # Look up Linux system dependencies at build time. The service reports one
  # distribution per call, so query Debian/Ubuntu and Fedora/RedHat separately.
  # as.list() forces JSON array shape so the JS consumer can iterate even when
  # a distro has exactly one system package.
  if (language == "r" && length(packages) > 0) {
    manifest$system_deps <- list(
      debian = as.list(query_sysreqs(packages, "ubuntu", "24.04")),
      fedora = as.list(query_sysreqs(packages, "redhat", "9"))
    )
  }

  jsonlite::toJSON(manifest, pretty = TRUE, auto_unbox = TRUE)
}

#' Resolve application dependencies
#'
#' Top-level function that detects, merges, and returns the final list of
#' package dependencies for an app. Called from export() for native app types.
#'
#' @param appdir Character string. Path to the app directory.
#' @param app_type Character string. The app type (`"r-shiny"` or `"py-shiny"`).
#' @param runtime_strategy Character string. The resolved runtime strategy.
#'   Returns NULL when `"shinylive"`, since shinylive manages its own deps.
#' @param config List. The effective configuration.
#' @return List with `packages`, `language`, and `repos`/`index_urls`,
#'   or NULL for the shinylive strategy.
#' @keywords internal
resolve_app_dependencies <- function(appdir, app_type, runtime_strategy, config) {
  if (runtime_strategy == "shinylive") {
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
